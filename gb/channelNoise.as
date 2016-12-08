import "libc";
import "./apu";
import "./bits";

// Channel 4 — Noise
struct ChannelNoise {
  APU: *apu.APU;

  // On/Off
  Enable: bool;

  // Linear Feedback Shift Register — 15-bit
  LFSR: uint16;

  // Volume * — Same as channel 1/2
  Volume: uint8;
  VolumeInitial: uint8;
  VolumeEnvelopeTimer: uint8;
  VolumeEnvelopePeriod: uint8;
  VolumeEnvelopeDirection: bool;

  // Length — Same as channel 1/2
  Length: uint8;
  LengthEnable: bool;

  // Timer — Same operation as channel 1/2 but set to:
  //         <divisor> << <frequency>
  Timer: uint16;

  // Shift Clock Frequency — 4 bits
  Frequency: uint8;

  // Counter Step/Width
  //  false=15 bits, true=7 bits
  CounterWidth: bool;

  // Divisor Index
  DivisorIndex: uint8;
}

implement ChannelNoise {
  def New(apu_: *apu.APU): Self {
    let ch: ChannelNoise;
    ch.APU = apu_;

    return ch;
  }

  def Reset(self) {
    self.Enable = false;
    self.LFSR = 0;
    self.Timer = 0;
    self.Frequency = 0;
    self.Volume = 0;
    self.VolumeInitial = 0;
    self.VolumeEnvelopeTimer = 0;
    self.VolumeEnvelopePeriod = 0;
    self.VolumeEnvelopeDirection = false;
    self.Length = 0;
    self.LengthEnable = false;
    self.CounterWidth = false;
    self.DivisorIndex = 0;
  }

  def Trigger(self) {
    // Channel is enabled (see length counter).
    self.Enable = true;

    // If length counter is zero, it is set to 64 (256 for wave channel).
    if self.Length == 0 { self.Length = 64; }

    // Frequency timer is reloaded with period.
    self.Timer = (getDivisor(self.DivisorIndex) << self.Frequency);

    // Volume envelope timer is reloaded with period.
    self.VolumeEnvelopeTimer = self.VolumeEnvelopePeriod;

    // Channel volume is reloaded from NRx2.
    self.Volume = self.VolumeInitial;

    // Noise channel's LFSR bits are all set to 1.
    self.LFSR = 0x7FFF;
  }

  def Tick(self) {
    if self.Timer > 0 { self.Timer -= 1; }
    if self.Timer == 0 {
      // When clocked by the frequency timer, the low two bits (0 and 1)
      // are XORed
      let b = bits.Test(uint8(self.LFSR), 0) ^ bits.Test(uint8(self.LFSR), 1);
      // All bits are shifted right by one
      self.LFSR >>= 1;
      // And the result of the XOR is put into the now-empty high bit
      if b { self.LFSR |= 0x4000; }
      // If width mode is 1 (NR43), the XOR result is ALSO put into
      // bit 6 AFTER the shift, resulting in a 7-bit LFSR.
      if self.CounterWidth {
        self.LFSR = (self.LFSR & ~0x40) | uint16(bits.Bit(b, 6));
      }

      // Reload timer
      self.Timer = (getDivisor(self.DivisorIndex) << self.Frequency);
    }
  }

  def TickLength(self) {
    if self.Length > 0 { self.Length -= 1; }
    if self.Length == 0 and self.LengthEnable {
      self.Enable = false;
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

  def Sample(self): int16 {
    // The waveform output is bit 0 of the LFSR, INVERTED
    let bit = not bits.Test(uint8(self.LFSR), 0);

    return int16(self.Volume if bit else 0);
  }

  // FF20 - NR41 - Channel 4 Sound Length (R)
  //    Bit 5-0 - Sound length data (t1: 0-63)

  // FF21 - NR42 - Channel 4 Volume Envelope (R/W)
  //    Bit 7-4 - Initial Volume of envelope (0-0Fh) (0=No Sound)
  //    Bit 3   - Envelope Direction (0=Decrease, 1=Increase)
  //    Bit 2-0 - Number of envelope sweep (n: 0-7)
  //              (If zero, stop envelope operation.)

  // FF22 - NR43 - Channel 4 Polynomial Counter (R/W)
  //    Bit 7-4 - Shift Clock Frequency (s)
  //    Bit 3   - Counter Step/Width (0=15 bits, 1=7 bits)
  //    Bit 2-0 - Dividing Ratio of Frequencies (r)

  // FF23 - NR44 - Channel 4 Counter/consecutive; Inital (R/W)
  //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  //    Bit 6   - Counter/consecutive selection (Read/Write)
  //              (1=Stop output when length in NR41 expires)

  def Read(self, address: uint16, ptr: *uint8): bool {
    // Check if we are at the right channel
    if (address < 0xFF20 or address > 0xFF23) { return false; }

    *ptr = if address == 0xFF21 {
      (
        (self.VolumeInitial << 4) |
        bits.Bit(self.VolumeEnvelopeDirection, 3) |
        self.VolumeEnvelopePeriod
      );
    } else if address == 0xFF22 {
      (
        (self.Frequency << 4) |
        bits.Bit(self.CounterWidth, 3) |
        self.DivisorIndex
      );
    } else if address == 0xFF23 {
      (bits.Bit(self.LengthEnable, 6) | 0xBF);
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    // Check if we are at the right channel
    if (address < 0xFF20 or address > 0xFF23) { return false; }

    // If master is disabled; ignore
    if not self.APU.Enable { return true; }

    if address == 0xFF20 {
      self.Length = 64 - (value & 0b1_1111);
    } else if address == 0xFF21 {
      self.VolumeInitial = (value & 0b1111_0000) >> 4;
      self.Volume = self.VolumeInitial;
      self.VolumeEnvelopeDirection = bits.Test(value, 3);
      self.VolumeEnvelopePeriod = (value & 0b111);
      self.VolumeEnvelopeTimer = self.VolumeEnvelopePeriod;
    } else if address == 0xFF22 {
      self.Frequency = (value >> 4);
      self.Timer = (getDivisor(self.DivisorIndex) << self.Frequency);
      self.CounterWidth = bits.Test(value, 3);
      self.DivisorIndex = (value & 0b111);
    } else if address == 0xFF23 {
      self.LengthEnable = bits.Test(value, 6);

      if bits.Test(value, 7) {
        self.Trigger();
      }
    } else {
      return false;
    };

    return true;
  }
}

def getDivisor(index: uint8): uint16 {
  return
    if      index == 1 {  16; }
    else if index == 2 {  32; }
    else if index == 3 {  48; }
    else if index == 4 {  64; }
    else if index == 5 {  80; }
    else if index == 6 {  96; }
    else if index == 7 { 112; }
    else               {   8; };
}
