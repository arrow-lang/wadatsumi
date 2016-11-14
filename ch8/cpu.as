import "std";
import "libc";

import "./op";
import "./machine";
import "./mmu";

// Reset
def reset(c: *machine.Context) {
  // TODO: Zero out other registers
  (*c).PC = 0x200;
}

// Execute
def execute(c: *machine.Context) {
  // Read next opcode and increment PC
  let opcode = mmu.at(c, (*c).PC);

  // Decode and execute opcode
  op.execute(c, opcode);

  // Tick the CPU
  // NOTE: Each operation is exactly 1 tick
  machine.tick(c);
}
