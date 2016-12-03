import "libc";
import "./cpu";
import "./mmu";

struct Timer {
  CPU: *cpu.CPU;

  /// Divider Register (R/W) — $FF04
  /// This register is incremented at rate of 16384Hz (~16779Hz on SGB).
  /// In CGB Double Speed Mode it is incremented twice as fast, ie. at 32768Hz.
  /// Writing any value to this register resets it to 00h.
  DIV: uint16;

  /// Timer Counter (R/W) — $FF05
  /// This timer is incremented by a clock frequency specified by the TAC
  /// register ($FF07). When the value overflows (gets bigger than FFh)
  /// then it will be reset to the value specified in TMA (FF06), and an
  /// interrupt will be requested.
  TIMA: uint8;

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
  }

  def Tick(self) {
    // If we have the TAC enable bit set, then we need to check for a 1 - 0
    // conversion on a specific bit. This figures out which bit.
    //  1 -> b03
    //  2 -> b05
    //  3 -> b07
    //  0 -> b09
    let freq = self.TAC & 0b11;
    let b = 0x200 if freq == 0 else (0x1 << ((freq << 1) + 1));

    // DIV increments on each T-cycle; this `tick` routine is called
    // on each M-cycle (which is exactly 4 T-cycles).
    let n = 0;
    while n < 4 {
      // Remember the value of our watched bit on DIV
      let oldBit = self.DIV & b;

      // Increment DIV
      self.DIV += 1;

      if (self.TAC & 0b100) != 0 and oldBit > 0 and (self.DIV & b) == 0 {
        // Check for 8-bit overflow
        if (uint16(self.TIMA) + 1) & 0xFF == 0 {
          // Set the overflow sentinel
          self.TIMA = self.TMA;

          // Flag the interrupt
          self.CPU.IF |= 0b100;
        } else {
          // Increment TIMA
          self.TIMA += 1;
        }
      }

      n += 1;
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

def MCRelease(this: *mmu.MemoryController) {
  // Do nothing
}

def MCRead(this: *mmu.MemoryController, address: uint16, value: *uint8): bool {
  return (this.Data as *Timer).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *Timer).Write(address, value);
}
