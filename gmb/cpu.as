import "libc";
import "std";

import "./mmu";
import "./machine";
import "./op";

struct CPU {
  /// 16-bit program counter
  PC: uint16;

  /// 16-bit stack pointer
  SP: uint16;

  /// Interrupt Master Enable (IME)
  ///  -1 - OFF
  ///   0 - PENDING
  ///  +1 - ON
  IME: int8;

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

  /// Number of M (machine) cycles for the current instruction
  /// Reset before each operation
  Cycles: uint32;

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

    self.AF = 0x01B0;
    self.BC = 0x0013;
    self.DE = 0x00D8;
    self.HL = 0x014D;
  }

  /// Tick
  /// Steps the machine and records the M-cycle
  def Tick(self) {
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
    // libc.printf("PC: $%04X AF: $%04X BC: $%04X DE: $%04X HL: $%04X SP: $%04X\n",
      buffer,
      self.PC - 1,
      self.AF,
      self.BC,
      self.DE,
      self.HL,
      self.SP,
    );
  }

  def ReadNext(self): uint8 {
    let result = self.MMU.Read(self.PC);
    self.PC += 1;

    return result;
  }
}
