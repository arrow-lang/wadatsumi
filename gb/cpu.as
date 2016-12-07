import "libc";
import "std";

import "./mmu";
import "./machine";
import "./op";
import "./om";

struct CPU {
  /// 16-bit program counter
  PC: uint16;

  /// 16-bit stack pointer
  SP: uint16;

  /// Interrupt Master Enable (IME)
  ///  -1 - Pending state that goes to ON
  ///   0 - OFF
  ///  +1 - ON
  IME: int8;

  // HALT
  //   0 - OFF
  //   1 - ON
  //  -1 - Funny bug state that will replay the next opcode
  HALT: int8;

  /// 16-bit registers
  AF: uint16;
  BC: uint16;
  DE: uint16;
  HL: uint16;

  /// 8-bit registers (pointers to nybbles in the 16-bit registers)
  A: *uint8;
  F: *uint8;
  B: *uint8;
  C: *uint8;
  D: *uint8;
  E: *uint8;
  H: *uint8;
  L: *uint8;

  /// Interrupt Enable (IE) R/W — $FFFF
  IE: uint8;

  /// Interrupt Flag (IF) R/W — $FF0F
  IF: uint8;

  /// Number of M (machine) cycles for the current instruction
  /// Reset before each operation
  Cycles: uint32;

  /// [OAM DMA] Start Address for the current DMA
  OAM_DMA_Start: uint16;

  /// [OAM DMA] Start Address of the next/pending DMA
  OAM_DMA_NextStart: uint16;

  /// [OAM DMA] Delay Timer until the next OMA DMA starts
  OAM_DMA_DelayTimer: uint8;

  /// [OAM DMA] Current index into the OAM DMA
  OAM_DMA_Index: uint16;

  /// [OAM DMA] Timer (in M-Cycles) of how long we have left in OAM DMA
  OAM_DMA_Timer: uint8;

  /// Memory management unit (reference)
  MMU: *mmu.MMU;

  /// Machine (reference)
  Machine: *machine.Machine;
}

implement CPU {
  def New(machine_: *machine.Machine, mmu_: *mmu.MMU): Self {
    let c: CPU;
    libc.memset(&c as *uint8, 0, std.size_of<CPU>());

    c.Machine = machine_;
    c.MMU = mmu_;

    return c;
  }

  def Acquire(self) {
    // Setup 8-bit register views
    self.A = ((&self.AF as *uint8) + 1);
    self.F = ((&self.AF as *uint8) + 0);
    self.B = ((&self.BC as *uint8) + 1);
    self.C = ((&self.BC as *uint8) + 0);
    self.D = ((&self.DE as *uint8) + 1);
    self.E = ((&self.DE as *uint8) + 0);
    self.H = ((&self.HL as *uint8) + 1);
    self.L = ((&self.HL as *uint8) + 0);
  }

  def Release(self) {
    // [...]
  }

  /// Reset
  def Reset(self) {
    self.PC = 0x0100;
    self.SP = 0xFFFE;
    self.IME = 1;
    self.HALT = 0;

    self.AF =
      if self.Machine.Mode == machine.MODE_CGB { 0x1180; }
      else                                     { 0x01B0; };

    self.BC =
      if self.Machine.Mode == machine.MODE_CGB { 0x0000; }
      else                                     { 0x0013; };

    self.DE =
      if self.Machine.Mode == machine.MODE_CGB { 0x0008; }
      else                                     { 0x00D8; };

    self.HL =
      if self.Machine.Mode == machine.MODE_CGB { 0x007C; }
      else                                     { 0x014D; };

    self.IE = 0x01;
    self.IF = 0x01;

    self.OAM_DMA_Start = 0;
    self.OAM_DMA_Index = 0;
    self.OAM_DMA_Timer = 0;
    self.OAM_DMA_NextStart = 0;
    self.OAM_DMA_DelayTimer = 0;
  }

  /// Tick
  /// Steps the machine and records the M-cycle
  def Tick(self) {
    // Run next iteration of OMA DMA (if active)
    if self.OAM_DMA_Timer > 0 {
      // Each tick does a single byte memory copy
      self.MMU.Write(0xFE00 + self.OAM_DMA_Index,
        self.MMU.Read(self.OAM_DMA_Start + self.OAM_DMA_Index));

      self.OAM_DMA_Index += 1;
      self.OAM_DMA_Timer -= 1;
    }

    // When OAM DMA starts a delay timer is set to 2; the tick with the memory
    // write that starts DMA and the tick just after are wait cycles before
    // the actual DMA starts. If there was an existing DMA running; that DMA
    // does not stop until the next one starts
    if self.OAM_DMA_DelayTimer > 0 {
      self.OAM_DMA_DelayTimer -= 1;
      if self.OAM_DMA_DelayTimer == 0 {
        self.OAM_DMA_Timer = 160;
        self.OAM_DMA_Index = 0;
        self.OAM_DMA_Start = self.OAM_DMA_NextStart;
      }
    }

    // Continue on to tick the machien state
    self.Machine.Tick();
    self.Cycles += 1;
  }

  /// Execute N instructions
  /// Returns the executed number of cycles
  def Run(self, this: *CPU, n: uint32): uint32 {
    let cycles: uint32 = 0;
    while (n + 1) > 0 {
      // Reset "current" cycle count
      self.Cycles = 0;

      // If during HALT and no pending interrupts ..
      if self.HALT == 1 {
        if (self.IE & self.IF & 0x1F) == 0 {
          self.Tick();
          cycles += self.Cycles;
          n -= 1;

          continue;
        } else if self.IME == 0 {
          // Just leave HALT mode (no interrupts are fired as
          // we do not have them enabled but we still exit HALT)
          self.HALT = 0;
        }
      }

      // Decide if we should service interrupts
      // No interrupts are allowed during OAM DMA
      let irq = self.IE & self.IF;
      if self.OAM_DMA_Timer == 0 and self.IME == 1 and irq > 0 {
        // Service interrupt (takes 5 cycles)

        // Wait 2 cycles
        self.Tick();
        self.Tick();

        // Push PC (as if we're making a CALL) – 2 cycles
        om.push16(this, &self.PC);

        // Jump to the appropriate vector (and reset IF bit) - 1 cycle
        if (irq & 0x01) != 0 {
          // V-Blank
          om.jp(this, 0x40, true);
          self.IF &= ~0x01;
        } else if (irq & 0x02) != 0 {
          // LCD STAT
          om.jp(this, 0x48, true);
          self.IF &= ~0x02;
        } else if (irq & 0x04) != 0 {
          // Timer
          om.jp(this, 0x50, true);
          self.IF &= ~0x04;
        } else if (irq & 0x08) != 0 {
          // Serial
          om.jp(this, 0x58, true);
          self.IF &= ~0x08;
        } else if (irq & 0x10) != 0 {
          // Joypad
          om.jp(this, 0x60, true);
          self.IF &= ~0x10;
        }

        // Disable IME
        self.IME = 0;

        // If coming back from halt; take 1 more cycle
        if self.HALT == 1 {
          self.HALT = 0;
          self.Tick();
        }
      }

      // Re-enable IME from pending
      if self.IME == -1 { self.IME = 1; }

      // Decode/lookup next operation
      let operation = op.next(this);

      // Print disassembly/trace
      // TODO: Make configurable from command line
      // self.Trace(operation);

      // Execute
      // HACK: Taking the address of a reference (`self`) dies
      operation.execute(this);

      // Increment total cycle count and let's do this again
      cycles += self.Cycles;
      n -= 1;
    }

    return cycles;
  }

  def Trace(self, operation: op.Operation) {
    let buffer: str;
    buffer = libc.malloc(128) as str;

    let n0 = self.MMU.Read(self.PC + 0);
    let n1 = self.MMU.Read(self.PC + 1);

    if operation.size == 2 {
      libc.sprintf(buffer, operation.disassembly, n0);
    } else if operation.size == 3 {
      libc.sprintf(buffer, operation.disassembly, n1, n0);
    } else {
      libc.sprintf(buffer, operation.disassembly);
    }

    libc.printf("trace: %-25s PC: $%04X AF: $%04X BC: $%04X DE: $%04X HL: $%04X SP: $%04X\n",
      buffer,
      self.PC - 1,
      self.AF,
      self.BC,
      self.DE,
      self.HL,
      self.SP,
    );
  }

  def Read(self, address: uint16, value: *uint8): bool {
    *value = if address == 0xFFFF {
      (self.IE | 0xE0);
    } else if address == 0xFF0F {
      (self.IF | 0xE0);
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if address == 0xFFFF {
      self.IE = value & ~0xE0;
    } else if address == 0xFF0F {
      self.IF = value & ~0xE0;
    } else if address == 0xFF46 {
      // DMA - DMA Transfer and Start Address (W)
      self.OAM_DMA_NextStart = uint16(value) << 8;
      self.OAM_DMA_DelayTimer = 2;
    } else {
      return false;
    }

    return true;
  }

  def AsMemoryController(self, this: *CPU): mmu.MemoryController {
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
  return (this.Data as *CPU).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *CPU).Write(address, value);
}
