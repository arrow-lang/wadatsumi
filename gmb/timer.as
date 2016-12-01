import "libc";
import "./cpu";

struct Timer {
  CPU: *cpu.CPU;

  /// Divider Register (R/W) — $FF04
  /// This register is incremented at rate of 16384Hz (~16779Hz on SGB).
  /// In CGB Double Speed Mode it is incremented twice as fast, ie. at 32768Hz.
  /// Writing any value to this register resets it to 00h.
  DIV: uint16;

  /// CPU Cycle counter for DIV rate
  DIVCycles: uint16;

  /// Timer Counter (R/W) — $FF05
  /// This timer is incremented by a clock frequency specified by the TAC
  /// register ($FF07). When the value overflows (gets bigger than FFh)
  /// then it will be reset to the value specified in TMA (FF06), and an
  /// interrupt will be requested.
  TIMA: uint8;

  /// CPU Cycle counter for TIMA rate
  TIMACycles: uint16;

  /// Timer Modulo (R/W) — $FF06
  /// When the TIMA overflows, this data will be loaded.
  TMA: uint8;

  /// Timer Control (R/W) — $FF07
  ///   Bit 2    - Timer Stop  (0=Stop, 1=Start)
  ///   Bits 1-0 - Input Clock Select
  ///            00:   4096 Hz    (~4194 Hz SGB)
  ///            01: 262144 Hz  (~268400 Hz SGB)
  ///            10:  65536 Hz   (~67110 Hz SGB)
  ///            11:  16384 Hz   (~16780 Hz SGB)
  TAC: uint8;
}

implement Timer {
  def New(): Self {
    let t: Timer;
    return t;
  }

  def Acquire(self, cpu_: *cpu.CPU) {
    self.CPU = cpu_;
  }

  def Reset(self) {
    self.DIV = 0;
    self.TIMA = 0;
    self.TMA = 0;
    self.TAC = 0;

    self.DIVCycles = 0;
    self.TIMACycles = 0;
  }

  def Tick(self) {
    // Increment DIV at a constant rate
    // Note that the gameboy operates on a rate that is significantly
    // slower than the source (CPU) rate. We need to find a ratio.
    //   GB: 16384 Hz      {4194304 Hz}   (256 : 1)
    //  SGB: 16779 Hz      {4295454 Hz}   (256 : 1)
    //  CGB: 32768 Hz (*)  {8400000 Hz}   (256 : 1)
    // Taking that into account.. every 256 CPU clocks (constant), the
    // DIV timer is ticked once. We measure in M-times which brings the
    // ratio to 64 CPU ticks per DIV tick.
    self.DIVCycles += 1;
    if self.DIVCycles >= 64 {
      self.DIV += 1;
      self.DIVCycles -= 64;
    }

    // Check if we need to mess with TIMA ..
    if self.TAC & 0b100 != 0 {
      // Get ratio (in Hz) – same math as earlier
      // TODO: Use SGB/CGB rates if in SGB/CGB mode
      let ratio = if (self.TAC & 0b11) == 0b11 {
        64;
      } else if (self.TAC & 0b11) == 0b10 {
        16;
      } else if (self.TAC & 0b11) == 0b01 {
        4;
      } else {
        256;
      };

      self.TIMACycles += 1;
      if self.TIMACycles >= ratio {
        // Check for 8-bit overflow
        if (uint16(self.TIMA) + 1) & 0xFF == 0 {
          // Set the overflow sentinel
          self.TIMA = self.TMA;

          // Flag the interrupt
          self.CPU.IF |= 0b100;
        } else {
          self.TIMA += 1;
        }

        self.TIMACycles -= ratio;
      }
    }
  }

  def Read(self, address: uint16, value: *uint8): bool {
    *value = if address == 0xFF04 {
      uint8(self.DIV >> 8);
    } else if address == 0xFF05 {
      self.TIMA;
    } else if address == 0xFF06 {
      self.TMA;
    } else if address == 0xFF07 {
      (self.TAC | 0b1111_1000);
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if address == 0xFF04 {
      self.DIV = 0;
    } else if address == 0xFF05 {
      self.TIMA = value;
    } else if address == 0xFF06 {
      self.TMA = value;
    } else if address == 0xFF07 {
      self.TAC = (value & 0b111);

      // If TIMA is disabled; clear cycle count
      if self.TAC & 0b100 == 0 {
        self.TIMACycles = 0;
      }
    } else {
      return false;
    }

    return true;
  }

  def AsMemoryController(self, this: *Timer): mmu.MemoryController {
    let mc: mmu.MemoryController;
    mc.Read = MCRead;
    mc.Write = MCWrite;
    mc.Data = this as *uint8;
    mc.Release = MCRelease;

    return mc;
  }
}

def MCRelease(this: *MemoryController) {
  // Do nothing
}

def MCRead(this: *MemoryController, address: uint16, value: *uint8): bool {
  return (this.Data as *Timer).Read(address, value);
}

def MCWrite(this: *MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *Timer).Write(address, value);
}
