import "libc";
import "./apu";
import "./bits";

// Channel 3 — Wave
struct ChannelWave {
  APU: *apu.APU;

  // Internal On/Off for this channel
  Enable: bool;

  // "DAC" Enable -- essentially an enable flag that is touchable
  DACEnable: bool;

  // Position in WAVE
  Position: uint8;

  // Sample Buffer
  Buffer: uint8;

  // Length — Same as channel 1/2 except that this is 8-bits and the
  //          square channels have 6-bits
  Length: uint8;
  LengthEnable: bool;

  // Volume — 2-bit code that indicates volume data
  //   00 — silence
  //   01 — (100%) data
  //   10 — ( 50%) data >> 1
  //   11 — ( 25%) data >> 2
  Volume: uint8;

  // Timer — Same as channel 1/2 except this is set to (2048-<frequency>)*2
  Timer: uint16;

  // Frequency — Same as channel 1/2
  Frequency: uint16;

  // Wave Pattern RAM (16 B)
  //  Waveform storage for arbitrary sound data
  //  Holds 32 4-bit samples that are played back upper 4 bits first
  RAM: *uint8;
}

implement ChannelWave {
  def New(apu_: *apu.APU): Self {
    let ch: ChannelWave;
    ch.APU = apu_;

    ch.RAM = libc.malloc(16);

    // On initial power, the WAVE ram has a particular pattern
    // according to model
    // Reset does NOT re-set this
    *(ch.RAM + 0x0) = 0x84;
    *(ch.RAM + 0x1) = 0x40;
    *(ch.RAM + 0x2) = 0x43;
    *(ch.RAM + 0x3) = 0xAA;
    *(ch.RAM + 0x4) = 0x2D;
    *(ch.RAM + 0x5) = 0x78;
    *(ch.RAM + 0x6) = 0x92;
    *(ch.RAM + 0x7) = 0x3C;
    *(ch.RAM + 0x8) = 0x60;
    *(ch.RAM + 0x9) = 0x59;
    *(ch.RAM + 0xA) = 0x59;
    *(ch.RAM + 0xB) = 0xB0;
    *(ch.RAM + 0xC) = 0x34;
    *(ch.RAM + 0xD) = 0xB8;
    *(ch.RAM + 0xE) = 0x2E;
    *(ch.RAM + 0xF) = 0xDA;

    return ch;
  }

  def Reset(self) {
    self.Position = 0;
    self.Enable = false;
    self.DACEnable = false;
    self.Length = 0;
    self.LengthEnable = false;
    self.Volume = 0;
    self.Timer = 0;
    self.Frequency = 0;
    self.Buffer = 0;
  }

  def Release(self) {
    libc.free(self.RAM);
  }

  def Trigger(self) {
    // Channel is enabled.
    self.Enable = true;

    // If length counter is zero, it is set to 64 (256 for wave channel).
    if self.Length == 0 { self.Length = 256; }

    // Frequency timer is reloaded with period.
    self.Timer = (2048 - self.Frequency) * 2;

    // Wave channel's position is set to 0 but sample buffer is NOT refilled.
    self.Position = 0;
  }

  def Tick(self) {
    if self.Timer > 0 { self.Timer -= 1; }
    if self.Timer == 0 {
      // Increment position in the duty pattern
      self.Position += 1;
      if self.Position == 32 { self.Position = 0; }

      // Fill the sample buffer
      //  <position> / 2 = wave index
      self.Buffer = *(self.RAM + (self.Position / 2));
      //  <position> % 2 = 0 (hi) or 1 (lo)
      self.Buffer >>= (1 - (self.Position % 2)) * 4;
      self.Buffer &= 0x0F;

      // Reload timer
      self.Timer = (2048 - self.Frequency) * 2;
    }
  }

  def TickLength(self) {
    if self.Length > 0 { self.Length -= 1; }
    if self.Length == 0 and self.LengthEnable {
      self.Enable = false;
    }
  }

  def Sample(self): int16 {
    if not (self.Enable and self.DACEnable) { return 0; }

    // The DAC receives the current value from the upper/lower nibble of the
    // sample buffer, shifted right by the volume control.
    return int16(self.Buffer >> (self.Volume - 1 if self.Volume > 0 else 4));
  }

  // FF1A - NR30 - Channel 3 Sound on/off (R/W)
  //    Bit 7 - Sound Channel 3 Off  (0=Stop, 1=Playback)  (Read/Write)

  // FF1B - NR31 - Channel 3 Sound Length (W)
  //    Bit 7-0 - Sound length (t1: 0 - 255)

  // FF1C - NR32 - Channel 3 Select output level (R/W)
  //    Bit 6-5 - Select output level (Read/Write)

  // FF1D - NR33 - Channel 3 Frequency's lower data (W)

  // FF1E - NR34 - Channel 3 Frequency's higher data (R/W)
  //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  //    Bit 6   - Counter/consecutive selection (Read/Write)
  //              (1=Stop output when length in NR31 expires)
  //    Bit 2-0 - Frequency's higher 3 bits (x) (Write Only)

  // FF30-FF3F - Wave Pattern RAM (16 bytes)
  // Contents - Waveform storage for arbitrary sound data

  def Read(self, address: uint16, ptr: *uint8): bool {
    // WAVE RAM is not affected by master on/off
    if address >= 0xFF30 and address <= 0xFF3F {
      *ptr = *(self.RAM + (address - 0xFF30));

      return true;
    }

    // Check if we are at the right channel
    if (address < 0xFF1A or address > 0xFF1E) { return false; }

    *ptr = if address == 0xFF1A {
      (bits.Bit(self.DACEnable, 7) | 0b0111_1111);
    } else if address == 0xFF1B {
      // FIXME: I have no idea if this supposed to be readable or not
      uint8((int16(self.Length) - 256) * -1);
    } else if address == 0xFF1C {
      ((self.Volume << 5) | 0b1001_1111);
    } else if address == 0xFF1E {
      (bits.Bit(self.LengthEnable, 6) | 0b1011_1111);
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    // WAVE RAM is not affected by master on/off
    if address >= 0xFF30 and address <= 0xFF3F {
      *(self.RAM + (address - 0xFF30)) = value;

      return true;
    }

    // Check if we are at the right channel
    if (address < 0xFF1A or address > 0xFF1E) { return false; }

    // If master is disabled; ignore
    if not self.APU.Enable { return true; }

    if address == 0xFF1A {
      self.DACEnable = bits.Test(value, 7);
    } else if address == 0xFF1B {
      self.Length = 256 - value;
    } else if address == 0xFF1C {
      self.Volume = ((value & 0b0110_0000) >> 5);
    } else if address == 0xFF1D {
      self.Frequency = (self.Frequency & ~0xFF) | uint16(value);
    } else if address == 0xFF1E {
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
