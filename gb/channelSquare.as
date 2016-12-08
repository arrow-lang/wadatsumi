import "./bits";
import "./apu";
import "libc";

// Channel 1/2 — Tone & Sweep
struct ChannelSquare {
  APU: *apu.APU;

  // Channel Index — 1 or 2
  ChannelIndex: uint8;

  // Enable — On/Off
  Enable: bool;

  // Timer
  //  Set to (2048 - <frequency>)*4
  //  Each CPU M-Cycle this is decremented
  //  When 0, reset back and push a waveform
  Timer: uint16;

  // Frequency
  //  11-bit value in NRx3 and NRx4
  Frequency: uint16;

  // Sweep Timer
  SweepTimer: uint8;

  // Sweep Enable (internal)
  SweepEnable: bool;

  // Sweep Frequency — Shadow copy of frequency used in sweep
  SweepFrequency: uint16;

  // Sweep period
  SweepPeriod: uint8;

  // Sweep Increase/Decrease Direction
  //  true  = increase
  //  false = decrease
  SweepDirection: bool;

  // Sweep Shift
  SweepShift: uint8;

  // Current volume of channel — same range as VolumeInitial
  Volume: uint8;

  // Initial volume on trigger — [$0, $F] (where $0 is silence)
  VolumeInitial: uint8;

  // Volume envelope timer
  //  Set to <volume envelope period>
  //  On the 7th step of the frame sequencer; it decrements
  //  When 0, increase or decrease volume
  //    according to <volume envelope direction> unless reached min/max
  VolumeEnvelopeTimer: uint8;

  // Volume envelope period — explained above
  VolumeEnvelopePeriod: uint8;

  // Volume envelope direction
  //  true  = increase
  //  false = decrease
  VolumeEnvelopeDirection: bool;

  // Length Counter
  //  Writing to NRx1 loads this as 64-<n>
  //  Every other step of the frame sequencer; it decrements
  //  When 0; channel is silenced
  Length: uint8;

  // Length Counter Enable
  //  When false a length=0 does not silence the channel
  LengthEnable: bool;

  // Duty Pattern Position
  DutyPosition: uint8;

  // Duty Pattern Index
  //  0 — 00000001 (12.5%)
  //  1 — 10000001 (25.0%)
  //  2 — 10000111 (50.0%)
  //  3 — 01111110 (75.0%)
  DutyIndex: uint8;
}

implement ChannelSquare {
  def New(channelIndex: uint8, apu_: *apu.APU): Self {
    let ch: ChannelSquare;
    ch.ChannelIndex = channelIndex;
    ch.APU = apu_;

    return ch;
  }

  def Reset(self) {
    self.Enable = false;
    self.Timer = 0;
    self.Frequency = 0;
    self.SweepEnable = false;
    self.SweepPeriod = 0;
    self.SweepDirection = false;
    self.SweepShift = 0;
    self.SweepTimer = 0;
    self.Volume = 0;
    self.VolumeInitial = 0;
    self.VolumeEnvelopeTimer = 0;
    self.VolumeEnvelopePeriod = 0;
    self.VolumeEnvelopeDirection = false;
    self.Length = 0;
    self.LengthEnable = false;
    self.DutyPosition = 0;
    self.DutyIndex = 0;
  }

  // From writing b7 to NRx4
  def Trigger(self) {
    self.DutyPosition = 0;

    // Channel is enabled (see length counter).
    self.Enable = true;

    // If length counter is zero, it is set to 64 (256 for wave channel).
    if self.Length == 0 { self.Length = 64; }

    // Frequency timer is reloaded with period.
    self.Timer = (2048 - self.Frequency) * 4;

    // Volume envelope timer is reloaded with period.
    self.VolumeEnvelopeTimer = self.VolumeEnvelopePeriod;

    // Channel volume is reloaded from NRx2.
    self.Volume = self.VolumeInitial;

    // Square 1's sweep does several things.
    self.SweepFrequency = self.Frequency;
    self.SweepTimer = self.SweepPeriod;
    self.SweepEnable = self.SweepPeriod > 0 or self.SweepShift > 0;
    if self.SweepShift > 0 { self.CalculateSweep(); }
  }

  def CalculateSweep(self): uint16 {
    // Calculate new frequency using sweep
    let r: uint16 = 0;
    r = self.SweepFrequency >> self.SweepShift;
    r = self.SweepFrequency + (r * (-1 if self.SweepDirection else +1));

    // Disable channel if overflow
    if r > 2047 {
      self.Enable = false;
    }

    return r;
  }

  def Tick(self) {
    if self.Timer > 0 { self.Timer -= 1; }
    if self.Timer == 0 {
      // Increment position in the duty pattern
      self.DutyPosition += 1;
      if self.DutyPosition == 8 { self.DutyPosition = 0; }

      // Reload timer
      self.Timer = (2048 - self.Frequency) * 4;
    }
  }

  def TickSweep(self) {
    if self.SweepTimer > 0 { self.SweepTimer -= 1; }
    if self.SweepPeriod > 0 {
      if self.SweepEnable and self.SweepTimer == 0 {
        let newFrequency = self.CalculateSweep();
        if newFrequency <= 2047 and self.SweepShift > 0 {
          self.SweepFrequency = newFrequency;
          self.Frequency = newFrequency;

          self.CalculateSweep();
        }

        self.SweepTimer = self.SweepPeriod;
      }
    }
  }

  def TickVolumeEnvelope(self) {
    if self.VolumeEnvelopePeriod > 0 {
      if self.VolumeEnvelopeTimer > 0 { self.VolumeEnvelopeTimer -= 1; }
      if self.VolumeEnvelopeTimer == 0 {
        if self.VolumeEnvelopeDirection {
          if self.Volume < 0xF {
            self.Volume += 1;
          }
        } else {
          if self.Volume > 0 {
            self.Volume -= 1;
          }
        }

        self.VolumeEnvelopeTimer = self.VolumeEnvelopePeriod;
      }
    }
  }

  def TickLength(self) {
    if self.Length > 0 { self.Length -= 1; }
    if self.Length == 0 and self.LengthEnable {
      self.Enable = false;
    }
  }

  def Sample(self): int16 {
    if not self.Enable { return 0; }

    let pattern = getDutyPattern(self.DutyIndex);
    let bit = bits.Test(pattern, (7 - self.DutyPosition));

    return int16(self.Volume if bit else 0);
  }

  // Register Read & Write

  // FFx0 - NRx0 - Channel 1 Sweep register (R/W)
  //    Bit 6-4 - Sweep Time
  //    Bit 3   - Sweep Increase/Decrease
  //               0: Addition    (frequency increases)
  //               1: Subtraction (frequency decreases)
  //    Bit 2-0 - Number of sweep shift (n: 0-7)

  // FFx1 - NRx1 - Channel 1 Sound length/Wave pattern duty (R/W)
  //    Bit 7-6 - Wave Pattern Duty (Read/Write)
  //    Bit 5-0 - Sound length data (Write Only) (t1: 0-63)

  // FFx2 - NRx2 - Channel 1 Volume Envelope (R/W)
  //    Bit 7-4 - Initial Volume of envelope (0-0Fh) (0=No Sound)
  //    Bit 3   - Envelope Direction (0=Decrease, 1=Increase)
  //    Bit 2-0 - Number of envelope sweep (n: 0-7)
  //              (If zero, stop envelope operation.)

  // FFx3 - NRx3 - Channel 1 Frequency lo (Write Only)

  // FFx4 - NRx4 - Channel 1 Frequency hi (R/W)
  //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  //    Bit 6   - Counter/consecutive selection (Read/Write)
  //              (1=Stop output when length in NR11 expires)
  //    Bit 2-0 - Frequency's higher 3 bits (x) (Write Only)

  def Read(self, address: uint16, ptr: *uint8): bool {
    // Check if we are at the right channel
    if (
      (self.ChannelIndex == 1 and (address < 0xFF10 or address > 0xFF14)) or
      (self.ChannelIndex == 2 and (address < 0xFF16 or address > 0xFF19))
    ) {
      return false;
    }

    let r = (address & 0xF) % 5;
    *ptr = if (r == 0 and self.ChannelIndex == 1) {
      (
        bits.Bit(true, 7) |
        (self.SweepPeriod << 4) |
        bits.Bit(self.SweepDirection, 3) |
        self.SweepShift
      );
    } else if r == 1 {
      ((self.DutyIndex << 6) | 0b11_1111);
    } else if r == 2 {
      (
        (self.VolumeInitial << 4) |
        bits.Bit(self.VolumeEnvelopeDirection, 3) |
        self.VolumeEnvelopePeriod
      );
    } else if r == 4 {
      (bits.Bit(self.LengthEnable, 6) | 0xBF);
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    // Check if we are at the right channel
    if (
      (self.ChannelIndex == 1 and (address < 0xFF10 or address > 0xFF14)) or
      (self.ChannelIndex == 2 and (address < 0xFF16 or address > 0xFF19))
    ) {
      return false;
    }

    // If master is disabled; ignore
    if not self.APU.Enable { return true; }

    let r = (address & 0xF) % 5;
    if (r == 0 and self.ChannelIndex == 1) {
      self.SweepPeriod = (value & 0b0111_0000) >> 4;
      self.SweepDirection = bits.Test(value, 3);
      self.SweepShift = (value & 0b111);
    } else if r == 1 {
      self.DutyIndex = (value & 0b1100_0000) >> 6;
      self.Length = 64 - (value & 0b1_1111);
    } else if r == 2 {
      self.VolumeInitial = (value & 0b1111_0000) >> 4;
      self.Volume = self.VolumeInitial;
      self.VolumeEnvelopeDirection = bits.Test(value, 3);
      self.VolumeEnvelopePeriod = (value & 0b111);
      self.VolumeEnvelopeTimer = self.VolumeEnvelopePeriod;
    } else if r == 3 {
      self.Frequency = (self.Frequency & ~0xFF) | uint16(value);
    } else if r == 4 {
      self.Frequency = (self.Frequency & ~0xF00) | (uint16(value & 0b111) << 8);
      self.LengthEnable = bits.Test(value, 6);

      if bits.Test(value, 7) {
        self.Trigger();
      }
    } else {
      return false;
    }

    return true;
  }
}

def getDutyPattern(dutyIndex: uint8): uint8 {
  return if dutyIndex == 0b11 {
    0b01111110;
  } else if dutyIndex == 0b10 {
    0b10000111;
  } else if dutyIndex == 0b01 {
    0b10000001;
  } else {
    0b00000001;
  };
}
