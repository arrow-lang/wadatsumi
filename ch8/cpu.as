import "std";
import "libc";

import "./op";
import "./machine";
import "./mmu";

// Reset
def reset(c: *machine.Context) {
  // TODO: Zero out other registers
  c.PC = 0x200;
}

// Execute Next Operation
def execute(c: *machine.Context) {
  // Read next opcode and increment PC
  let opcode = mmu.at(c, c.PC);

  // Increment PC
  c.PC += 2;

  // Decode and execute opcode
  op.execute(c, opcode);
}
