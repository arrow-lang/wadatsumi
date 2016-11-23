import "./cpu";

struct Operation {
  // Operation handler
  execute: (*cpu.CPU) -> ();

  // Disassembly (string format)
  disassembly: str;

  // Number of bytes (incl. opcode)
  size: uint8;
}

let table = [0x100]Operation{
  Operation{_00, "NOP",                    1},
  Operation{_01, "LD BC, %02X",            2},
};

// 00 — NOP
def _00(c: *cpu.CPU) {
  // Do nothing
}

// 01 nn — LD BC, nn
def _01(c: *cpu.CPU) {
}
