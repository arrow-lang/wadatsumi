import "std";
import "libc";

import "./mmu";
import "./bits";

// TODO: Re-organize registers rather than blind bytes

struct APU {
  // Channel 1 - Tone & Sweep
  // ------------------------

  // FF10 - NR10 - Channel 1 Sweep register (R/W)
  //    Bit 6-4 - Sweep Time
  //    Bit 3   - Sweep Increase/Decrease
  //               0: Addition    (frequency increases)
  //               1: Subtraction (frequency decreases)
  //    Bit 2-0 - Number of sweep shift (n: 0-7)
  NR10: uint8;

  // FF11 - NR11 - Channel 1 Sound length/Wave pattern duty (R/W)
  //    Bit 7-6 - Wave Pattern Duty (Read/Write)
  //    Bit 5-0 - Sound length data (Write Only) (t1: 0-63)
  NR11: uint8;

  // FF12 - NR12 - Channel 1 Volume Envelope (R/W)
  //    Bit 7-4 - Initial Volume of envelope (0-0Fh) (0=No Sound)
  //    Bit 3   - Envelope Direction (0=Decrease, 1=Increase)
  //    Bit 2-0 - Number of envelope sweep (n: 0-7)
  //              (If zero, stop envelope operation.)
  NR12: uint8;

  // FF13 - NR13 - Channel 1 Frequency lo (Write Only)
  NR13: uint8;

  // FF14 - NR14 - Channel 1 Frequency hi (R/W)
  //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  //    Bit 6   - Counter/consecutive selection (Read/Write)
  //              (1=Stop output when length in NR11 expires)
  //    Bit 2-0 - Frequency's higher 3 bits (x) (Write Only)
  NR14: uint8;

  // Channel 2 - Tone
  // ----------------

  // FF16 - NR21 - Channel 2 Sound Length/Wave Pattern Duty (R/W)
  //    Bit 7-6 - Wave Pattern Duty (Read/Write)
  //    Bit 5-0 - Sound length data (Write Only) (t1: 0-63)
  NR21: uint8;

  // FF17 - NR22 - Channel 2 Volume Envelope (R/W)
  //    Bit 7-4 - Initial Volume of envelope (0-0Fh) (0=No Sound)
  //    Bit 3   - Envelope Direction (0=Decrease, 1=Increase)
  //    Bit 2-0 - Number of envelope sweep (n: 0-7)
  //              (If zero, stop envelope operation.)
  NR22: uint8;

  // FF18 - NR23 - Channel 2 Frequency lo data (W)
  NR23: uint8;

  // FF19 - NR24 - Channel 2 Frequency hi data (R/W)
  //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  //    Bit 6   - Counter/consecutive selection (Read/Write)
  //              (1=Stop output when length in NR21 expires)
  //    Bit 2-0 - Frequency's higher 3 bits (x) (Write Only)
  NR24: uint8;

  // Channel 3 - Wave Output
  // -----------------------

  // FF1A - NR30 - Channel 3 Sound on/off (R/W)
  //    Bit 7 - Sound Channel 3 Off  (0=Stop, 1=Playback)  (Read/Write)
  NR30: uint8;

  // FF1B - NR31 - Channel 3 Sound Length (R/W)
  //    Bit 7-0 - Sound length (t1: 0 - 255)
  NR31: uint8;

  // FF1C - NR32 - Channel 3 Select output level (R/W)
  //    Bit 6-5 - Select output level (Read/Write)
  NR32: uint8;

  // FF1D - NR33 - Channel 3 Frequency's lower data (W)
  NR33: uint8;

  // FF1E - NR34 - Channel 3 Frequency's higher data (R/W)
  //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  //    Bit 6   - Counter/consecutive selection (Read/Write)
  //              (1=Stop output when length in NR31 expires)
  //    Bit 2-0 - Frequency's higher 3 bits (x) (Write Only)
  NR34: uint8;

  // FF30-FF3F - Wave Pattern RAM (16 bytes)
  // Contents - Waveform storage for arbitrary sound data
  C3_WavePatternRAM: *uint8;

  // Channel 4 - Noise
  // -----------------

  // FF20 - NR41 - Channel 4 Sound Length (R/W)
  //    Bit 5-0 - Sound length data (t1: 0-63)
  NR41: uint8;

  // FF21 - NR42 - Channel 4 Volume Envelope (R/W)
  //    Bit 7-4 - Initial Volume of envelope (0-0Fh) (0=No Sound)
  //    Bit 3   - Envelope Direction (0=Decrease, 1=Increase)
  //    Bit 2-0 - Number of envelope sweep (n: 0-7)
  //              (If zero, stop envelope operation.)
  NR42: uint8;

  // FF22 - NR43 - Channel 4 Polynomial Counter (R/W)
  //    Bit 7-4 - Shift Clock Frequency (s)
  //    Bit 3   - Counter Step/Width (0=15 bits, 1=7 bits)
  //    Bit 2-0 - Dividing Ratio of Frequencies (r)
  NR43: uint8;

  // FF23 - NR44 - Channel 4 Counter/consecutive; Inital (R/W)
  //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  //    Bit 6   - Counter/consecutive selection (Read/Write)
  //              (1=Stop output when length in NR41 expires)
  NR44: uint8;

  // Sound Control Registers
  // -----------------------

  // FF24 - NR50 - Channel control / ON-OFF / Volume (R/W)
  //    Bit 7   - Output Vin to SO2 terminal (1=Enable)
  //    Bit 6-4 - SO2 output level (volume)  (0-7)
  //    Bit 3   - Output Vin to SO1 terminal (1=Enable)
  //    Bit 2-0 - SO1 output level (volume)  (0-7)
  NR50: uint8;

  // FF25 - NR51 - Selection of Sound output terminal (R/W)
  //    Bit 7 - Output sound 4 to SO2 terminal
  //    Bit 6 - Output sound 3 to SO2 terminal
  //    Bit 5 - Output sound 2 to SO2 terminal
  //    Bit 4 - Output sound 1 to SO2 terminal
  //    Bit 3 - Output sound 4 to SO1 terminal
  //    Bit 2 - Output sound 3 to SO1 terminal
  //    Bit 1 - Output sound 2 to SO1 terminal
  //    Bit 0 - Output sound 1 to SO1 terminal
  NR51: uint8;

  // FF26 - NR52 - Sound on/off
  //    Bit 7 - All sound on/off  (0: stop all sound circuits) (Read/Write)
  //    Bit 3 - Sound 4 ON flag (Read Only)
  //    Bit 2 - Sound 3 ON flag (Read Only)
  //    Bit 1 - Sound 2 ON flag (Read Only)
  //    Bit 0 - Sound 1 ON flag (Read Only)
  M_SoundEnabled: bool;
}

implement APU {
  def New(): Self {
    let component: APU;
    libc.memset(&component as *uint8, 0, std.size_of<APU>());

    component.C3_WavePatternRAM = libc.malloc(16);

    return component;
  }

  def Release(self) {
    libc.free(self.C3_WavePatternRAM);
  }

  def Read(self, address: uint16, ptr: *uint8): bool {
    *ptr = if address == 0xFF10 {
      (self.NR10 | 0x80);
    } else if address == 0xFF11 {
      (self.NR11 | 0b0011_1111);
    } else if address == 0xFF12 {
      self.NR12;
    } else if address == 0xFF14 {
      (self.NR14 | 0b1011_1111);
    } else if address == 0xFF16 {
      (self.NR21 | 0b0011_1111);
    } else if address == 0xFF17 {
      self.NR22;
    } else if address == 0xFF19 {
      (self.NR24 | 0b1011_1111);
    } else if address == 0xFF1A {
      (self.NR30 | 0b0111_1111);
    } else if address == 0xFF1B {
      self.NR31;
    } else if address == 0xFF1C {
      (self.NR32 | 0b1001_1111);
    } else if address == 0xFF1E {
      (self.NR34 | 0b1011_1111);
    } else if address == 0xFF20 {
      (self.NR41 | 0b1100_0000);
    } else if address == 0xFF21 {
      self.NR42;
    } else if address == 0xFF22 {
      self.NR43;
    } else if address == 0xFF23 {
      (self.NR44 | 0b1011_1111);
    } else if address == 0xFF24 {
      self.NR50;
    } else if address == 0xFF25 {
      self.NR51;
    } else if address == 0xFF26 {
      (
        bits.Bit(self.M_SoundEnabled, 7) |
        bits.Bit(true, 6) |
        bits.Bit(true, 5) |
        bits.Bit(true, 4) |
        // TODO: Compute actual ON/OFF of sound channel
        bits.Bit(false, 3) |
        bits.Bit(false, 2) |
        bits.Bit(false, 1) |
        bits.Bit(true, 0)
      );
    } else if address >= 0xFF30 and address <= 0xFF3F {
      *(self.C3_WavePatternRAM + (address - 0xFF30));
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if address == 0xFF10 {
      self.NR10 = (value & ~0x80);
    } else if address == 0xFF11 {
      self.NR11 = (value & 0xC0);
    } else if address == 0xFF12 {
      self.NR12 = value;
    } else if address == 0xFF13 {
      self.NR13 = value;
    } else if address == 0xFF14 {
      self.NR14 = value;
    } else if address == 0xFF16 {
      self.NR21 = value;
    } else if address == 0xFF17 {
      self.NR22 = value;
    } else if address == 0xFF18 {
      self.NR23 = value;
    } else if address == 0xFF19 {
      self.NR24 = value;
    } else if address == 0xFF1A {
      self.NR30 = (value & 0x80);
    } else if address == 0xFF1B {
      self.NR31 = value;
    } else if address == 0xFF1C {
      self.NR32 = value & 0x60;
    } else if address == 0xFF1D {
      self.NR33 = value;
    } else if address == 0xFF1E {
      self.NR34 = value;
    } else if address == 0xFF20 {
      self.NR41 = value & 0b11_1111;
    } else if address == 0xFF21 {
      self.NR42 = value;
    } else if address == 0xFF22 {
      self.NR43 = value;
    } else if address == 0xFF23 {
      self.NR44 = value & 0b1100_0000;
    } else if address == 0xFF24 {
      self.NR50 = value;
    } else if address == 0xFF25 {
      self.NR51 = value;
    } else if address == 0xFF26 {
      self.M_SoundEnabled = bits.Test(value, 7);
    } else if address >= 0xFF30 and address <= 0xFF3F {
      *(self.C3_WavePatternRAM + (address - 0xFF30)) = value;
    } else {
      return false;
    }

    return true;
  }

  def Tick(self) {
    // ...
  }

  def AsMemoryController(self, this: *APU): mmu.MemoryController {
    let mc: mmu.MemoryController;
    mc.Read = MCRead;
    mc.Write = MCWrite;
    mc.Data = this as *uint8;
    mc.Release = MCRelease;

    return mc;
  }
}

def MCRelease(this: *mmu.MemoryController) {
  // Do nothing
}

def MCRead(this: *mmu.MemoryController, address: uint16, value: *uint8): bool {
  return (this.Data as *APU).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *APU).Write(address, value);
}
