import "./cpu";

struct Operation {
  // Operation handler
  execute: (*cpu.CPU) -> ();

  // Disassembly (string format)
  disassembly: str;

  // Number of bytes (incl. opcode)
  size: uint8;
}

let nil = 0 as ((*cpu.CPU) -> ());
let table = [0x100]Operation{
  Operation{_00, "NOP",               1},
  Operation{_01, "LD BC, %02X",       2},
  Operation{_02, "LD (BC), A",        1},
  Operation{_03, "INC BC",            1},
  Operation{_04, "INC B",             1},
  Operation{_05, "DEC B",             1},
  Operation{_06, "LD B, %02X",        2},
  Operation{nil, "RLCA",              1},
  Operation{nil, "LD (%02X%02X), SP", 3},
  Operation{nil, "ADD HL, BC",        1},
  Operation{nil, "LD A, (BC)",        1},
  Operation{nil, "DEC BC",            1},
  Operation{nil, "INC C",             1},
  Operation{nil, "DEC C",             1},
  Operation{nil, "LD C, %02X",        2},
  Operation{nil, "RRCA",              1},
};

// For instructions which either read or write, but not both, the CPU makes
// the access on the last cycle.

// For instructions which read, modify, then
// write back, the CPU reads on the next-to-last cycle, and writes on the
// last cycle.

// 00 — NOP {1}
def _00(c: *cpu.CPU) {
  // Do nothing
}

// 01 nn — LD BC, u8 {3}
def _01(c: *cpu.CPU) {
  *(c.B) = c.mmu.read_next();
  c.tick();

  *(c.C) = c.mmu.read_next();
  c.tick();
}

// 02 — LD (BC), A {2}
def _02(c: *cpu.CPU) {
  c.mmu.write(c.BC, *(c.A));
  c.tick();
}

// 03 — INC BC {2}
def _03(c: *cpu.CPU) {
  c.BC = om.inc16(c.BC);
  c.tick();
}

// 04 — INC B {1}
def _04(c: *cpu.CPU) {
  *(c.B) = om.inc8(*(c.B));
}

// 05 — DEC B {1}
def _05(c: *cpu.CPU) {
  *(c.B) = om.dec8(*(c.B));
}

// 06 — LD B, u8
def _06(c: *cpu.CPU) {
  *(c.B) = c.mmu.read_next();
  c.tick();
}
