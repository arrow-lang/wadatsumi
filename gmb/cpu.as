import "./mmu";

struct CPU {
  /// 16-bit program counter
  PC: uint16;

  /// 16-bit stack pointer
  SP: uint16;

  /// Interrupt Master Enable (IME)
  IME: bool;

  /// 16-bit registers
  AF: uint16;
  BC: uint16;
  DE: uint16;
  HL: uint16;

  /// 8-bit registers (pointers to nybbles in the 16-bit registers)
  A: *uint8;
  B: *uint8;
  C: *uint8;
  D: *uint8;
  E: *uint8;
  H: *uint8;
  L: *uint8;

  /// Number of M (machine) cycles for the current instruction
  /// Reset before each operation
  cycles: uint16;

  /// Memory management unit (reference)
  mmu: *mmu.MMU;

  /// Machine (reference)
  machine: *machine.Machine;
}

implement CPU {
  def new(): Self {
    // ...
  }

  /// Tick
  /// Steps the machine and records the M-cycle
  def tick(self) {
    self.machine.tick();
    self.context.cycles += 1;
  }

  /// Execute N instructions
  /// Returns the executed number of cycles
  def execute(self, n: uint32): uint32 {
    let cycles = 0;
    while (n + 1) > 0 {
      // Reset "current" cycle count
      self.cycles = 0;

      // Read opcode
      let opcode = self.mmu.next8();
      self.tick();

      // Decode/lookup operation
      let operation = op.table[opcode];

      // Print disassembly/trace
      // TODO: self.trace(operation);

      // Execute
      operation.execute(self);

      // Increment total cycle count and let's do this again
      cycles += self.cycles;
      n -= 1;
    }

    return cycles;
  }
}
