import "std";
import "libc";

import "./cpu";
import "./om";

struct Operation {
  // Operation handler
  execute: (*cpu.CPU) -> ();

  // Disassembly (string format)
  disassembly: str;

  // Number of bytes (incl. opcode)
  size: uint8;
}

implement Operation {
  // TODO: After record literals .. this won't be needed
  def New(execute: (*cpu.CPU) -> (), disassembly: str, size: uint8): Self {
    let result: Operation;
    result.execute = execute;
    result.disassembly = disassembly;
    result.size = size;

    return result;
  }
}

// TODO: let table = [0x100]Operation{...}
let table: *Operation;
let table_CB: *Operation;
let tableSize = 0x1_00 * std.size_of<Operation>();

// TODO: Static arrays would render this unneeded
def acquire() {
  table = libc.malloc(tableSize) as *Operation;
  libc.memset(table as *uint8, 0, tableSize);

  *(table + 0x00) = Operation.New(_00, "NOP", 1);
  *(table + 0x01) = Operation.New(_01, "LD BC, $%02X%02X", 3);
  *(table + 0x02) = Operation.New(_02, "LD (BC), A", 1);
  *(table + 0x03) = Operation.New(_03, "INC BC", 1);
  *(table + 0x04) = Operation.New(_04, "INC B", 1);
  *(table + 0x05) = Operation.New(_05, "DEC B", 1);
  *(table + 0x06) = Operation.New(_06, "LD B, $%02X", 2);
  *(table + 0x07) = Operation.New(_07, "RLCA", 1);
  *(table + 0x08) = Operation.New(_08, "LD ($%02X%02X), SP", 3);
  *(table + 0x09) = Operation.New(_09, "ADD HL, BC", 1);
  *(table + 0x0A) = Operation.New(_0A, "LD A, (BC)", 1);
  *(table + 0x0B) = Operation.New(_0B, "DEC BC", 1);
  *(table + 0x0C) = Operation.New(_0C, "INC C", 1);
  *(table + 0x0D) = Operation.New(_0D, "DEC C", 1);
  *(table + 0x0E) = Operation.New(_0E, "LD C, $%02X", 2);
  *(table + 0x0F) = Operation.New(_0F, "RRCA", 1);

  *(table + 0x10) = Operation.New(_10, "STOP", 1);
  *(table + 0x11) = Operation.New(_11, "LD DE, $%02X%02X", 3);
  *(table + 0x12) = Operation.New(_12, "LD (DE), A", 1);
  *(table + 0x13) = Operation.New(_13, "INC DE", 1);
  *(table + 0x14) = Operation.New(_14, "INC D", 1);
  *(table + 0x15) = Operation.New(_15, "DEC D", 1);
  *(table + 0x16) = Operation.New(_16, "LD D, $%02X", 2);
  *(table + 0x17) = Operation.New(_17, "RLA", 1);
  *(table + 0x18) = Operation.New(_18, "JR $%02X", 2);
  *(table + 0x19) = Operation.New(_19, "ADD HL, DE", 1);
  *(table + 0x1A) = Operation.New(_1A, "LD A, (DE)", 1);
  *(table + 0x1B) = Operation.New(_1B, "DEC DE", 1);
  *(table + 0x1C) = Operation.New(_1C, "INC E", 1);
  *(table + 0x1D) = Operation.New(_1D, "DEC E", 1);
  *(table + 0x1E) = Operation.New(_1E, "LD E, $%02X", 2);
  *(table + 0x1F) = Operation.New(_1F, "RRA", 1);

  *(table + 0x20) = Operation.New(_20, "JR NZ, $%02X", 2);
  *(table + 0x21) = Operation.New(_21, "LD HL, $%02X%02X", 3);
  *(table + 0x22) = Operation.New(_22, "LDI (HL), A", 1);
  *(table + 0x23) = Operation.New(_23, "INC HL", 1);
  *(table + 0x24) = Operation.New(_24, "INC H", 1);
  *(table + 0x25) = Operation.New(_25, "DEC H", 1);
  *(table + 0x26) = Operation.New(_26, "LD H, $%02X", 2);
  *(table + 0x27) = Operation.New(_27, "DAA", 1);
  *(table + 0x28) = Operation.New(_28, "JR Z, $%02X", 2);
  *(table + 0x29) = Operation.New(_29, "ADD HL, HL", 1);
  *(table + 0x2A) = Operation.New(_2A, "LDI A, (HL)", 1);
  *(table + 0x2B) = Operation.New(_2B, "DEC HL", 1);
  *(table + 0x2C) = Operation.New(_2C, "INC L", 1);
  *(table + 0x2D) = Operation.New(_2D, "DEC L", 1);
  *(table + 0x2E) = Operation.New(_2E, "LD L, $%02X", 2);
  *(table + 0x2F) = Operation.New(_2F, "CPL", 1);

  *(table + 0x30) = Operation.New(_30, "JR NC, $%02X", 2);
  *(table + 0x31) = Operation.New(_31, "LD SP, ($%02X%02X)", 3);
  *(table + 0x32) = Operation.New(_32, "LDD (HL), A", 1);
  *(table + 0x33) = Operation.New(_33, "INC SP", 1);
  *(table + 0x34) = Operation.New(_34, "INC (HL)", 1);
  *(table + 0x35) = Operation.New(_35, "DEC (HL)", 1);
  *(table + 0x36) = Operation.New(_36, "LD (HL), $%02X", 2);
  *(table + 0x37) = Operation.New(_37, "SCF", 1);
  *(table + 0x38) = Operation.New(_38, "JR C, $%02X", 2);
  *(table + 0x39) = Operation.New(_39, "ADD HL, SP", 1);
  *(table + 0x3A) = Operation.New(_3A, "LDD A, (HL)", 1);
  *(table + 0x3B) = Operation.New(_3B, "DEC SP", 1);
  *(table + 0x3C) = Operation.New(_3C, "INC A", 1);
  *(table + 0x3D) = Operation.New(_3D, "DEC A", 1);
  *(table + 0x3E) = Operation.New(_3E, "LD A, $%02X", 2);
  *(table + 0x3F) = Operation.New(_3F, "CCF", 1);

  *(table + 0x40) = Operation.New(_40, "LD B, B", 1);
  *(table + 0x41) = Operation.New(_41, "LD B, C", 1);
  *(table + 0x42) = Operation.New(_42, "LD B, D", 1);
  *(table + 0x43) = Operation.New(_43, "LD B, E", 1);
  *(table + 0x44) = Operation.New(_44, "LD B, H", 1);
  *(table + 0x45) = Operation.New(_45, "LD B, L", 1);
  *(table + 0x46) = Operation.New(_46, "LD B, (HL)", 1);
  *(table + 0x47) = Operation.New(_47, "LD B, A", 1);
  *(table + 0x48) = Operation.New(_48, "LD C, B", 1);
  *(table + 0x49) = Operation.New(_49, "LD C, C", 1);
  *(table + 0x4A) = Operation.New(_4A, "LD C, D", 1);
  *(table + 0x4B) = Operation.New(_4B, "LD C, E", 1);
  *(table + 0x4C) = Operation.New(_4C, "LD C, H", 1);
  *(table + 0x4D) = Operation.New(_4D, "LD C, L", 1);
  *(table + 0x4E) = Operation.New(_4E, "LD C, (HL)", 1);
  *(table + 0x4F) = Operation.New(_4F, "LD C, A", 1);

  *(table + 0x50) = Operation.New(_50, "LD D, B", 1);
  *(table + 0x51) = Operation.New(_51, "LD D, C", 1);
  *(table + 0x52) = Operation.New(_52, "LD D, D", 1);
  *(table + 0x53) = Operation.New(_53, "LD D, E", 1);
  *(table + 0x54) = Operation.New(_54, "LD D, H", 1);
  *(table + 0x55) = Operation.New(_55, "LD D, L", 1);
  *(table + 0x56) = Operation.New(_56, "LD D, (HL)", 1);
  *(table + 0x57) = Operation.New(_57, "LD D, A", 1);
  *(table + 0x58) = Operation.New(_58, "LD E, B", 1);
  *(table + 0x59) = Operation.New(_59, "LD E, C", 1);
  *(table + 0x5A) = Operation.New(_5A, "LD E, D", 1);
  *(table + 0x5B) = Operation.New(_5B, "LD E, E", 1);
  *(table + 0x5C) = Operation.New(_5C, "LD E, H", 1);
  *(table + 0x5D) = Operation.New(_5D, "LD E, L", 1);
  *(table + 0x5E) = Operation.New(_5E, "LD E, (HL)", 1);
  *(table + 0x5F) = Operation.New(_5F, "LD E, A", 1);

  *(table + 0x60) = Operation.New(_60, "LD H, B", 1);
  *(table + 0x61) = Operation.New(_61, "LD H, C", 1);
  *(table + 0x62) = Operation.New(_62, "LD H, D", 1);
  *(table + 0x63) = Operation.New(_63, "LD H, E", 1);
  *(table + 0x64) = Operation.New(_64, "LD H, H", 1);
  *(table + 0x65) = Operation.New(_65, "LD H, L", 1);
  *(table + 0x66) = Operation.New(_66, "LD H, (HL)", 1);
  *(table + 0x67) = Operation.New(_67, "LD H, A", 1);
  *(table + 0x68) = Operation.New(_68, "LD L, B", 1);
  *(table + 0x69) = Operation.New(_69, "LD L, C", 1);
  *(table + 0x6A) = Operation.New(_6A, "LD L, D", 1);
  *(table + 0x6B) = Operation.New(_6B, "LD L, E", 1);
  *(table + 0x6C) = Operation.New(_6C, "LD L, H", 1);
  *(table + 0x6D) = Operation.New(_6D, "LD L, L", 1);
  *(table + 0x6E) = Operation.New(_6E, "LD L, (HL)", 1);
  *(table + 0x6F) = Operation.New(_6F, "LD L, A", 1);

  *(table + 0x70) = Operation.New(_70, "LD (HL), B", 1);
  *(table + 0x71) = Operation.New(_71, "LD (HL), C", 1);
  *(table + 0x72) = Operation.New(_72, "LD (HL), D", 1);
  *(table + 0x73) = Operation.New(_73, "LD (HL), E", 1);
  *(table + 0x74) = Operation.New(_74, "LD (HL), H", 1);
  *(table + 0x75) = Operation.New(_75, "LD (HL), L", 1);
  *(table + 0x76) = Operation.New(_76, "HALT", 1);
  *(table + 0x77) = Operation.New(_77, "LD (HL), A", 1);
  *(table + 0x78) = Operation.New(_78, "LD A, B", 1);
  *(table + 0x79) = Operation.New(_79, "LD A, C", 1);
  *(table + 0x7A) = Operation.New(_7A, "LD A, D", 1);
  *(table + 0x7B) = Operation.New(_7B, "LD A, E", 1);
  *(table + 0x7C) = Operation.New(_7C, "LD A, H", 1);
  *(table + 0x7D) = Operation.New(_7D, "LD A, L", 1);
  *(table + 0x7E) = Operation.New(_7E, "LD A, (HL)", 1);
  *(table + 0x7F) = Operation.New(_7F, "LD A, A", 1);

  *(table + 0x80) = Operation.New(_80, "ADD A, B", 1);
  *(table + 0x81) = Operation.New(_81, "ADD A, C", 1);
  *(table + 0x82) = Operation.New(_82, "ADD A, D", 1);
  *(table + 0x83) = Operation.New(_83, "ADD A, E", 1);
  *(table + 0x84) = Operation.New(_84, "ADD A, H", 1);
  *(table + 0x85) = Operation.New(_85, "ADD A, L", 1);
  *(table + 0x86) = Operation.New(_86, "ADD A, (HL)", 1);
  *(table + 0x87) = Operation.New(_87, "ADD A, A", 1);
  *(table + 0x88) = Operation.New(_88, "ADC A, B", 1);
  *(table + 0x89) = Operation.New(_89, "ADC A, C", 1);
  *(table + 0x8A) = Operation.New(_8A, "ADC A, D", 1);
  *(table + 0x8B) = Operation.New(_8B, "ADC A, E", 1);
  *(table + 0x8C) = Operation.New(_8C, "ADC A, H", 1);
  *(table + 0x8D) = Operation.New(_8D, "ADC A, L", 1);
  *(table + 0x8E) = Operation.New(_8E, "ADC A, (HL)", 1);
  *(table + 0x8F) = Operation.New(_8F, "ADC A, A", 1);

  *(table + 0x90) = Operation.New(_90, "SUB A, B", 1);
  *(table + 0x91) = Operation.New(_91, "SUB A, C", 1);
  *(table + 0x92) = Operation.New(_92, "SUB A, D", 1);
  *(table + 0x93) = Operation.New(_93, "SUB A, E", 1);
  *(table + 0x94) = Operation.New(_94, "SUB A, H", 1);
  *(table + 0x95) = Operation.New(_95, "SUB A, L", 1);
  *(table + 0x96) = Operation.New(_96, "SUB A, (HL)", 1);
  *(table + 0x97) = Operation.New(_97, "SUB A, A", 1);
  *(table + 0x98) = Operation.New(_98, "SBC A, B", 1);
  *(table + 0x99) = Operation.New(_99, "SBC A, C", 1);
  *(table + 0x9A) = Operation.New(_9A, "SBC A, D", 1);
  *(table + 0x9B) = Operation.New(_9B, "SBC A, E", 1);
  *(table + 0x9C) = Operation.New(_9C, "SBC A, H", 1);
  *(table + 0x9D) = Operation.New(_9D, "SBC A, L", 1);
  *(table + 0x9E) = Operation.New(_9E, "SBC A, (HL)", 1);
  *(table + 0x9F) = Operation.New(_9F, "SBC A, A", 1);

  *(table + 0xA0) = Operation.New(_A0, "AND A, B", 1);
  *(table + 0xA1) = Operation.New(_A1, "AND A, C", 1);
  *(table + 0xA2) = Operation.New(_A2, "AND A, D", 1);
  *(table + 0xA3) = Operation.New(_A3, "AND A, E", 1);
  *(table + 0xA4) = Operation.New(_A4, "AND A, H", 1);
  *(table + 0xA5) = Operation.New(_A5, "AND A, L", 1);
  *(table + 0xA6) = Operation.New(_A6, "AND A, (HL)", 1);
  *(table + 0xA7) = Operation.New(_A7, "AND A, A", 1);
  *(table + 0xA8) = Operation.New(_A8, "XOR A, B", 1);
  *(table + 0xA9) = Operation.New(_A9, "XOR A, C", 1);
  *(table + 0xAA) = Operation.New(_AA, "XOR A, D", 1);
  *(table + 0xAB) = Operation.New(_AB, "XOR A, E", 1);
  *(table + 0xAC) = Operation.New(_AC, "XOR A, H", 1);
  *(table + 0xAD) = Operation.New(_AD, "XOR A, L", 1);
  *(table + 0xAE) = Operation.New(_AE, "XOR A, (HL)", 1);
  *(table + 0xAF) = Operation.New(_AF, "XOR A, A", 1);

  *(table + 0xB0) = Operation.New(_B0, "OR A, B", 1);
  *(table + 0xB1) = Operation.New(_B1, "OR A, C", 1);
  *(table + 0xB2) = Operation.New(_B2, "OR A, D", 1);
  *(table + 0xB3) = Operation.New(_B3, "OR A, E", 1);
  *(table + 0xB4) = Operation.New(_B4, "OR A, H", 1);
  *(table + 0xB5) = Operation.New(_B5, "OR A, L", 1);
  *(table + 0xB6) = Operation.New(_B6, "OR A, (HL)", 1);
  *(table + 0xB7) = Operation.New(_B7, "OR A, A", 1);
  *(table + 0xB8) = Operation.New(_B8, "CP A, B", 1);
  *(table + 0xB9) = Operation.New(_B9, "CP A, C", 1);
  *(table + 0xBA) = Operation.New(_BA, "CP A, D", 1);
  *(table + 0xBB) = Operation.New(_BB, "CP A, E", 1);
  *(table + 0xBC) = Operation.New(_BC, "CP A, H", 1);
  *(table + 0xBD) = Operation.New(_BD, "CP A, L", 1);
  *(table + 0xBE) = Operation.New(_BE, "CP A, (HL)", 1);
  *(table + 0xBF) = Operation.New(_BF, "CP A, A", 1);

  *(table + 0xC0) = Operation.New(_C0, "RET NZ", 1);
  *(table + 0xC1) = Operation.New(_C1, "POP BC", 1);
  *(table + 0xC2) = Operation.New(_C2, "JP NZ, $%02X%02X", 3);
  *(table + 0xC3) = Operation.New(_C3, "JP $%02X%02X", 3);
  *(table + 0xC4) = Operation.New(_C4, "CALL NZ, $%02X%02X", 3);
  *(table + 0xC5) = Operation.New(_C5, "PUSH BC", 1);
  *(table + 0xC6) = Operation.New(_C6, "ADD A, $%02X", 2);
  *(table + 0xC7) = Operation.New(_C7, "RST $00", 1);
  *(table + 0xC8) = Operation.New(_C8, "RET Z", 1);
  *(table + 0xC9) = Operation.New(_C9, "RET", 1);
  *(table + 0xCA) = Operation.New(_CA, "JP Z, $%02X%02X", 3);
  *(table + 0xCC) = Operation.New(_CC, "CALL Z, $%02X%02X", 3);
  *(table + 0xCD) = Operation.New(_CD, "CALL $%02X%02X", 3);
  *(table + 0xCE) = Operation.New(_CE, "ADC A, $%02X", 2);
  *(table + 0xCF) = Operation.New(_CF, "RST $08", 1);

  *(table + 0xD0) = Operation.New(_D0, "RET NC", 1);
  *(table + 0xD1) = Operation.New(_D1, "POP DE", 1);
  *(table + 0xD2) = Operation.New(_D2, "JP NC, $%02X%02X", 3);
  *(table + 0xD4) = Operation.New(_D4, "CALL NC, $%02X%02X", 3);
  *(table + 0xD5) = Operation.New(_D5, "PUSH DE", 1);
  *(table + 0xD6) = Operation.New(_D6, "SUB A, $%02X", 2);
  *(table + 0xD7) = Operation.New(_D7, "RST $10", 1);
  *(table + 0xD8) = Operation.New(_D8, "RET C", 1);
  *(table + 0xD9) = Operation.New(_D9, "RETI", 1);
  *(table + 0xDA) = Operation.New(_DA, "JP C, $%02X%02X", 3);
  *(table + 0xDC) = Operation.New(_DC, "CALL C, $%02X%02X", 3);
  *(table + 0xDE) = Operation.New(_DE, "SBC A, $%02X", 2);
  *(table + 0xDF) = Operation.New(_DF, "RST $18", 1);

  *(table + 0xE0) = Operation.New(_E0, "LD ($FF00 + $%02X), A", 2);
  *(table + 0xE1) = Operation.New(_E1, "POP HL", 1);
  *(table + 0xE2) = Operation.New(_E2, "LD (C), A", 1);
  *(table + 0xE5) = Operation.New(_E5, "PUSH HL", 1);
  *(table + 0xE6) = Operation.New(_E6, "AND A, $%02X", 2);
  *(table + 0xE7) = Operation.New(_E7, "RST $20", 1);
  *(table + 0xE8) = Operation.New(_E8, "ADD SP, %02X", 2);
  *(table + 0xE9) = Operation.New(_E9, "JP HL", 1);
  *(table + 0xEA) = Operation.New(_EA, "LD ($%02X%02X), A", 3);
  *(table + 0xEE) = Operation.New(_EE, "XOR A, $%02X", 2);
  *(table + 0xEF) = Operation.New(_EF, "RST $28", 1);

  *(table + 0xF0) = Operation.New(_F0, "LD A, ($FF00 + $%02X)", 2);
  *(table + 0xF1) = Operation.New(_F1, "POP AF", 1);
  *(table + 0xF2) = Operation.New(_F2, "LD A, (C)", 3);
  *(table + 0xF3) = Operation.New(_F3, "DI", 1);
  *(table + 0xF5) = Operation.New(_F5, "PUSH AF", 1);
  *(table + 0xF6) = Operation.New(_F6, "OR A, $%02X", 2);
  *(table + 0xF7) = Operation.New(_F7, "RST $30", 1);
  *(table + 0xF8) = Operation.New(_F8, "LD HL, SP + $%02X", 2);
  *(table + 0xF9) = Operation.New(_F9, "LD SP, HL", 1);
  *(table + 0xFA) = Operation.New(_FA, "LD A, ($%02X%02X)", 3);
  *(table + 0xFB) = Operation.New(_FB, "EI", 1);
  *(table + 0xFE) = Operation.New(_FE, "CP A, $%02X", 2);
  *(table + 0xFF) = Operation.New(_FF, "RST $38", 1);

  table_CB = libc.malloc(tableSize) as *Operation;
  libc.memset(table_CB as *uint8, 0, tableSize);

  *(table_CB + 0x00) = Operation.New(_CB_00, "RLC B", 1);
  *(table_CB + 0x01) = Operation.New(_CB_01, "RLC C", 1);
  *(table_CB + 0x02) = Operation.New(_CB_02, "RLC D", 1);
  *(table_CB + 0x03) = Operation.New(_CB_03, "RLC E", 1);
  *(table_CB + 0x04) = Operation.New(_CB_04, "RLC H", 1);
  *(table_CB + 0x05) = Operation.New(_CB_05, "RLC L", 1);
  *(table_CB + 0x06) = Operation.New(_CB_06, "RLC (HL)", 1);
  *(table_CB + 0x07) = Operation.New(_CB_07, "RLC A", 1);
  *(table_CB + 0x08) = Operation.New(_CB_08, "RRC B", 1);
  *(table_CB + 0x09) = Operation.New(_CB_09, "RRC C", 1);
  *(table_CB + 0x0A) = Operation.New(_CB_0A, "RRC D", 1);
  *(table_CB + 0x0B) = Operation.New(_CB_0B, "RRC E", 1);
  *(table_CB + 0x0C) = Operation.New(_CB_0C, "RRC H", 1);
  *(table_CB + 0x0D) = Operation.New(_CB_0D, "RRC L", 1);
  *(table_CB + 0x0E) = Operation.New(_CB_0E, "RRC (HL)", 1);
  *(table_CB + 0x0F) = Operation.New(_CB_0F, "RRC A", 1);

  *(table_CB + 0x10) = Operation.New(_CB_10, "RL B", 1);
  *(table_CB + 0x11) = Operation.New(_CB_11, "RL C", 1);
  *(table_CB + 0x12) = Operation.New(_CB_12, "RL D", 1);
  *(table_CB + 0x13) = Operation.New(_CB_13, "RL E", 1);
  *(table_CB + 0x14) = Operation.New(_CB_14, "RL H", 1);
  *(table_CB + 0x15) = Operation.New(_CB_15, "RL L", 1);
  *(table_CB + 0x16) = Operation.New(_CB_16, "RL (HL)", 1);
  *(table_CB + 0x17) = Operation.New(_CB_17, "RL A", 1);
  *(table_CB + 0x18) = Operation.New(_CB_18, "RR B", 1);
  *(table_CB + 0x19) = Operation.New(_CB_19, "RR C", 1);
  *(table_CB + 0x1A) = Operation.New(_CB_1A, "RR D", 1);
  *(table_CB + 0x1B) = Operation.New(_CB_1B, "RR E", 1);
  *(table_CB + 0x1C) = Operation.New(_CB_1C, "RR H", 1);
  *(table_CB + 0x1D) = Operation.New(_CB_1D, "RR L", 1);
  *(table_CB + 0x1E) = Operation.New(_CB_1E, "RR (HL)", 1);
  *(table_CB + 0x1F) = Operation.New(_CB_1F, "RR A", 1);

  *(table_CB + 0x20) = Operation.New(_CB_20, "SLA B", 1);
  *(table_CB + 0x21) = Operation.New(_CB_21, "SLA C", 1);
  *(table_CB + 0x22) = Operation.New(_CB_22, "SLA D", 1);
  *(table_CB + 0x23) = Operation.New(_CB_23, "SLA E", 1);
  *(table_CB + 0x24) = Operation.New(_CB_24, "SLA H", 1);
  *(table_CB + 0x25) = Operation.New(_CB_25, "SLA L", 1);
  *(table_CB + 0x26) = Operation.New(_CB_26, "SLA (HL)", 1);
  *(table_CB + 0x27) = Operation.New(_CB_27, "SLA A", 1);
  *(table_CB + 0x28) = Operation.New(_CB_28, "SRA B", 1);
  *(table_CB + 0x29) = Operation.New(_CB_29, "SRA C", 1);
  *(table_CB + 0x2A) = Operation.New(_CB_2A, "SRA D", 1);
  *(table_CB + 0x2B) = Operation.New(_CB_2B, "SRA E", 1);
  *(table_CB + 0x2C) = Operation.New(_CB_2C, "SRA H", 1);
  *(table_CB + 0x2D) = Operation.New(_CB_2D, "SRA L", 1);
  *(table_CB + 0x2E) = Operation.New(_CB_2E, "SRA (HL)", 1);
  *(table_CB + 0x2F) = Operation.New(_CB_2F, "SRA A", 1);

  *(table_CB + 0x30) = Operation.New(_CB_30, "SWAP B", 1);
  *(table_CB + 0x31) = Operation.New(_CB_31, "SWAP C", 1);
  *(table_CB + 0x32) = Operation.New(_CB_32, "SWAP D", 1);
  *(table_CB + 0x33) = Operation.New(_CB_33, "SWAP E", 1);
  *(table_CB + 0x34) = Operation.New(_CB_34, "SWAP H", 1);
  *(table_CB + 0x35) = Operation.New(_CB_35, "SWAP L", 1);
  *(table_CB + 0x36) = Operation.New(_CB_36, "SWAP (HL)", 1);
  *(table_CB + 0x37) = Operation.New(_CB_37, "SWAP A", 1);
  *(table_CB + 0x38) = Operation.New(_CB_38, "SRL B", 1);
  *(table_CB + 0x39) = Operation.New(_CB_39, "SRL C", 1);
  *(table_CB + 0x3A) = Operation.New(_CB_3A, "SRL D", 1);
  *(table_CB + 0x3B) = Operation.New(_CB_3B, "SRL E", 1);
  *(table_CB + 0x3C) = Operation.New(_CB_3C, "SRL H", 1);
  *(table_CB + 0x3D) = Operation.New(_CB_3D, "SRL L", 1);
  *(table_CB + 0x3E) = Operation.New(_CB_3E, "SRL (HL)", 1);
  *(table_CB + 0x3F) = Operation.New(_CB_3F, "SRL A", 1);

  *(table_CB + 0x40) = Operation.New(_CB_40, "BIT 0, B", 1);
  *(table_CB + 0x41) = Operation.New(_CB_41, "BIT 0, C", 1);
  *(table_CB + 0x42) = Operation.New(_CB_42, "BIT 0, D", 1);
  *(table_CB + 0x43) = Operation.New(_CB_43, "BIT 0, E", 1);
  *(table_CB + 0x44) = Operation.New(_CB_44, "BIT 0, H", 1);
  *(table_CB + 0x45) = Operation.New(_CB_45, "BIT 0, L", 1);
  *(table_CB + 0x46) = Operation.New(_CB_46, "BIT 0, (HL)", 1);
  *(table_CB + 0x47) = Operation.New(_CB_47, "BIT 0, A", 1);
  *(table_CB + 0x48) = Operation.New(_CB_48, "BIT 1, B", 1);
  *(table_CB + 0x49) = Operation.New(_CB_49, "BIT 1, C", 1);
  *(table_CB + 0x4A) = Operation.New(_CB_4A, "BIT 1, D", 1);
  *(table_CB + 0x4B) = Operation.New(_CB_4B, "BIT 1, E", 1);
  *(table_CB + 0x4C) = Operation.New(_CB_4C, "BIT 1, H", 1);
  *(table_CB + 0x4D) = Operation.New(_CB_4D, "BIT 1, L", 1);
  *(table_CB + 0x4E) = Operation.New(_CB_4E, "BIT 1, (HL)", 1);
  *(table_CB + 0x4F) = Operation.New(_CB_4F, "BIT 1, A", 1);

  *(table_CB + 0x50) = Operation.New(_CB_50, "BIT 2, B", 1);
  *(table_CB + 0x51) = Operation.New(_CB_51, "BIT 2, C", 1);
  *(table_CB + 0x52) = Operation.New(_CB_52, "BIT 2, D", 1);
  *(table_CB + 0x53) = Operation.New(_CB_53, "BIT 2, E", 1);
  *(table_CB + 0x54) = Operation.New(_CB_54, "BIT 2, H", 1);
  *(table_CB + 0x55) = Operation.New(_CB_55, "BIT 2, L", 1);
  *(table_CB + 0x56) = Operation.New(_CB_56, "BIT 2, (HL)", 1);
  *(table_CB + 0x57) = Operation.New(_CB_57, "BIT 2, A", 1);
  *(table_CB + 0x58) = Operation.New(_CB_58, "BIT 3, B", 1);
  *(table_CB + 0x59) = Operation.New(_CB_59, "BIT 3, C", 1);
  *(table_CB + 0x5A) = Operation.New(_CB_5A, "BIT 3, D", 1);
  *(table_CB + 0x5B) = Operation.New(_CB_5B, "BIT 3, E", 1);
  *(table_CB + 0x5C) = Operation.New(_CB_5C, "BIT 3, H", 1);
  *(table_CB + 0x5D) = Operation.New(_CB_5D, "BIT 3, L", 1);
  *(table_CB + 0x5E) = Operation.New(_CB_5E, "BIT 3, (HL)", 1);
  *(table_CB + 0x5F) = Operation.New(_CB_5F, "BIT 3, A", 1);

  *(table_CB + 0x60) = Operation.New(_CB_60, "BIT 4, B", 1);
  *(table_CB + 0x61) = Operation.New(_CB_61, "BIT 4, C", 1);
  *(table_CB + 0x62) = Operation.New(_CB_62, "BIT 4, D", 1);
  *(table_CB + 0x63) = Operation.New(_CB_63, "BIT 4, E", 1);
  *(table_CB + 0x64) = Operation.New(_CB_64, "BIT 4, H", 1);
  *(table_CB + 0x65) = Operation.New(_CB_65, "BIT 4, L", 1);
  *(table_CB + 0x66) = Operation.New(_CB_66, "BIT 4, (HL)", 1);
  *(table_CB + 0x67) = Operation.New(_CB_67, "BIT 4, A", 1);
  *(table_CB + 0x68) = Operation.New(_CB_68, "BIT 5, B", 1);
  *(table_CB + 0x69) = Operation.New(_CB_69, "BIT 5, C", 1);
  *(table_CB + 0x6A) = Operation.New(_CB_6A, "BIT 5, D", 1);
  *(table_CB + 0x6B) = Operation.New(_CB_6B, "BIT 5, E", 1);
  *(table_CB + 0x6C) = Operation.New(_CB_6C, "BIT 5, H", 1);
  *(table_CB + 0x6D) = Operation.New(_CB_6D, "BIT 5, L", 1);
  *(table_CB + 0x6E) = Operation.New(_CB_6E, "BIT 5, (HL)", 1);
  *(table_CB + 0x6F) = Operation.New(_CB_6F, "BIT 5, A", 1);

  *(table_CB + 0x70) = Operation.New(_CB_70, "BIT 6, B", 1);
  *(table_CB + 0x71) = Operation.New(_CB_71, "BIT 6, C", 1);
  *(table_CB + 0x72) = Operation.New(_CB_72, "BIT 6, D", 1);
  *(table_CB + 0x73) = Operation.New(_CB_73, "BIT 6, E", 1);
  *(table_CB + 0x74) = Operation.New(_CB_74, "BIT 6, H", 1);
  *(table_CB + 0x75) = Operation.New(_CB_75, "BIT 6, L", 1);
  *(table_CB + 0x76) = Operation.New(_CB_76, "BIT 6, (HL)", 1);
  *(table_CB + 0x77) = Operation.New(_CB_77, "BIT 6, A", 1);
  *(table_CB + 0x78) = Operation.New(_CB_78, "BIT 7, B", 1);
  *(table_CB + 0x79) = Operation.New(_CB_79, "BIT 7, C", 1);
  *(table_CB + 0x7A) = Operation.New(_CB_7A, "BIT 7, D", 1);
  *(table_CB + 0x7B) = Operation.New(_CB_7B, "BIT 7, E", 1);
  *(table_CB + 0x7C) = Operation.New(_CB_7C, "BIT 7, H", 1);
  *(table_CB + 0x7D) = Operation.New(_CB_7D, "BIT 7, L", 1);
  *(table_CB + 0x7E) = Operation.New(_CB_7E, "BIT 7, (HL)", 1);
  *(table_CB + 0x7F) = Operation.New(_CB_7F, "BIT 7, A", 1);

  *(table_CB + 0x80) = Operation.New(_CB_80, "RES 0, B", 1);
  *(table_CB + 0x81) = Operation.New(_CB_81, "RES 0, C", 1);
  *(table_CB + 0x82) = Operation.New(_CB_82, "RES 0, D", 1);
  *(table_CB + 0x83) = Operation.New(_CB_83, "RES 0, E", 1);
  *(table_CB + 0x84) = Operation.New(_CB_84, "RES 0, H", 1);
  *(table_CB + 0x85) = Operation.New(_CB_85, "RES 0, L", 1);
  *(table_CB + 0x86) = Operation.New(_CB_86, "RES 0, (HL)", 1);
  *(table_CB + 0x87) = Operation.New(_CB_87, "RES 0, A", 1);
  *(table_CB + 0x88) = Operation.New(_CB_88, "RES 1, B", 1);
  *(table_CB + 0x89) = Operation.New(_CB_89, "RES 1, C", 1);
  *(table_CB + 0x8A) = Operation.New(_CB_8A, "RES 1, D", 1);
  *(table_CB + 0x8B) = Operation.New(_CB_8B, "RES 1, E", 1);
  *(table_CB + 0x8C) = Operation.New(_CB_8C, "RES 1, H", 1);
  *(table_CB + 0x8D) = Operation.New(_CB_8D, "RES 1, L", 1);
  *(table_CB + 0x8E) = Operation.New(_CB_8E, "RES 1, (HL)", 1);
  *(table_CB + 0x8F) = Operation.New(_CB_8F, "RES 1, A", 1);

  *(table_CB + 0x90) = Operation.New(_CB_90, "RES 2, B", 1);
  *(table_CB + 0x91) = Operation.New(_CB_91, "RES 2, C", 1);
  *(table_CB + 0x92) = Operation.New(_CB_92, "RES 2, D", 1);
  *(table_CB + 0x93) = Operation.New(_CB_93, "RES 2, E", 1);
  *(table_CB + 0x94) = Operation.New(_CB_94, "RES 2, H", 1);
  *(table_CB + 0x95) = Operation.New(_CB_95, "RES 2, L", 1);
  *(table_CB + 0x96) = Operation.New(_CB_96, "RES 2, (HL)", 1);
  *(table_CB + 0x97) = Operation.New(_CB_97, "RES 2, A", 1);
  *(table_CB + 0x98) = Operation.New(_CB_98, "RES 3, B", 1);
  *(table_CB + 0x99) = Operation.New(_CB_99, "RES 3, C", 1);
  *(table_CB + 0x9A) = Operation.New(_CB_9A, "RES 3, D", 1);
  *(table_CB + 0x9B) = Operation.New(_CB_9B, "RES 3, E", 1);
  *(table_CB + 0x9C) = Operation.New(_CB_9C, "RES 3, H", 1);
  *(table_CB + 0x9D) = Operation.New(_CB_9D, "RES 3, L", 1);
  *(table_CB + 0x9E) = Operation.New(_CB_9E, "RES 3, (HL)", 1);
  *(table_CB + 0x9F) = Operation.New(_CB_9F, "RES 3, A", 1);

  *(table_CB + 0xA0) = Operation.New(_CB_A0, "RES 4, B", 1);
  *(table_CB + 0xA1) = Operation.New(_CB_A1, "RES 4, C", 1);
  *(table_CB + 0xA2) = Operation.New(_CB_A2, "RES 4, D", 1);
  *(table_CB + 0xA3) = Operation.New(_CB_A3, "RES 4, E", 1);
  *(table_CB + 0xA4) = Operation.New(_CB_A4, "RES 4, H", 1);
  *(table_CB + 0xA5) = Operation.New(_CB_A5, "RES 4, L", 1);
  *(table_CB + 0xA6) = Operation.New(_CB_A6, "RES 4, (HL)", 1);
  *(table_CB + 0xA7) = Operation.New(_CB_A7, "RES 4, A", 1);
  *(table_CB + 0xA8) = Operation.New(_CB_A8, "RES 5, B", 1);
  *(table_CB + 0xA9) = Operation.New(_CB_A9, "RES 5, C", 1);
  *(table_CB + 0xAA) = Operation.New(_CB_AA, "RES 5, D", 1);
  *(table_CB + 0xAB) = Operation.New(_CB_AB, "RES 5, E", 1);
  *(table_CB + 0xAC) = Operation.New(_CB_AC, "RES 5, H", 1);
  *(table_CB + 0xAD) = Operation.New(_CB_AD, "RES 5, L", 1);
  *(table_CB + 0xAE) = Operation.New(_CB_AE, "RES 5, (HL)", 1);
  *(table_CB + 0xAF) = Operation.New(_CB_AF, "RES 5, A", 1);

  *(table_CB + 0xB0) = Operation.New(_CB_B0, "RES 6, B", 1);
  *(table_CB + 0xB1) = Operation.New(_CB_B1, "RES 6, C", 1);
  *(table_CB + 0xB2) = Operation.New(_CB_B2, "RES 6, D", 1);
  *(table_CB + 0xB3) = Operation.New(_CB_B3, "RES 6, E", 1);
  *(table_CB + 0xB4) = Operation.New(_CB_B4, "RES 6, H", 1);
  *(table_CB + 0xB5) = Operation.New(_CB_B5, "RES 6, L", 1);
  *(table_CB + 0xB6) = Operation.New(_CB_B6, "RES 6, (HL)", 1);
  *(table_CB + 0xB7) = Operation.New(_CB_B7, "RES 6, A", 1);
  *(table_CB + 0xB8) = Operation.New(_CB_B8, "RES 7, B", 1);
  *(table_CB + 0xB9) = Operation.New(_CB_B9, "RES 7, C", 1);
  *(table_CB + 0xBA) = Operation.New(_CB_BA, "RES 7, D", 1);
  *(table_CB + 0xBB) = Operation.New(_CB_BB, "RES 7, E", 1);
  *(table_CB + 0xBC) = Operation.New(_CB_BC, "RES 7, H", 1);
  *(table_CB + 0xBD) = Operation.New(_CB_BD, "RES 7, L", 1);
  *(table_CB + 0xBE) = Operation.New(_CB_BE, "RES 7, (HL)", 1);
  *(table_CB + 0xBF) = Operation.New(_CB_BF, "RES 7, A", 1);

  *(table_CB + 0xC0) = Operation.New(_CB_C0, "SET 0, B", 1);
  *(table_CB + 0xC1) = Operation.New(_CB_C1, "SET 0, C", 1);
  *(table_CB + 0xC2) = Operation.New(_CB_C2, "SET 0, D", 1);
  *(table_CB + 0xC3) = Operation.New(_CB_C3, "SET 0, E", 1);
  *(table_CB + 0xC4) = Operation.New(_CB_C4, "SET 0, H", 1);
  *(table_CB + 0xC5) = Operation.New(_CB_C5, "SET 0, L", 1);
  *(table_CB + 0xC6) = Operation.New(_CB_C6, "SET 0, (HL)", 1);
  *(table_CB + 0xC7) = Operation.New(_CB_C7, "SET 0, A", 1);
  *(table_CB + 0xC8) = Operation.New(_CB_C8, "SET 1, B", 1);
  *(table_CB + 0xC9) = Operation.New(_CB_C9, "SET 1, C", 1);
  *(table_CB + 0xCA) = Operation.New(_CB_CA, "SET 1, D", 1);
  *(table_CB + 0xCB) = Operation.New(_CB_CB, "SET 1, E", 1);
  *(table_CB + 0xCC) = Operation.New(_CB_CC, "SET 1, H", 1);
  *(table_CB + 0xCD) = Operation.New(_CB_CD, "SET 1, L", 1);
  *(table_CB + 0xCE) = Operation.New(_CB_CE, "SET 1, (HL)", 1);
  *(table_CB + 0xCF) = Operation.New(_CB_CF, "SET 1, A", 1);

  *(table_CB + 0xD0) = Operation.New(_CB_D0, "SET 2, B", 1);
  *(table_CB + 0xD1) = Operation.New(_CB_D1, "SET 2, C", 1);
  *(table_CB + 0xD2) = Operation.New(_CB_D2, "SET 2, D", 1);
  *(table_CB + 0xD3) = Operation.New(_CB_D3, "SET 2, E", 1);
  *(table_CB + 0xD4) = Operation.New(_CB_D4, "SET 2, H", 1);
  *(table_CB + 0xD5) = Operation.New(_CB_D5, "SET 2, L", 1);
  *(table_CB + 0xD6) = Operation.New(_CB_D6, "SET 2, (HL)", 1);
  *(table_CB + 0xD7) = Operation.New(_CB_D7, "SET 2, A", 1);
  *(table_CB + 0xD8) = Operation.New(_CB_D8, "SET 3, B", 1);
  *(table_CB + 0xD9) = Operation.New(_CB_D9, "SET 3, C", 1);
  *(table_CB + 0xDA) = Operation.New(_CB_DA, "SET 3, D", 1);
  *(table_CB + 0xDB) = Operation.New(_CB_DB, "SET 3, E", 1);
  *(table_CB + 0xDC) = Operation.New(_CB_DC, "SET 3, H", 1);
  *(table_CB + 0xDD) = Operation.New(_CB_DD, "SET 3, L", 1);
  *(table_CB + 0xDE) = Operation.New(_CB_DE, "SET 3, (HL)", 1);
  *(table_CB + 0xDF) = Operation.New(_CB_DF, "SET 3, A", 1);

  *(table_CB + 0xE0) = Operation.New(_CB_E0, "SET 4, B", 1);
  *(table_CB + 0xE1) = Operation.New(_CB_E1, "SET 4, C", 1);
  *(table_CB + 0xE2) = Operation.New(_CB_E2, "SET 4, D", 1);
  *(table_CB + 0xE3) = Operation.New(_CB_E3, "SET 4, E", 1);
  *(table_CB + 0xE4) = Operation.New(_CB_E4, "SET 4, H", 1);
  *(table_CB + 0xE5) = Operation.New(_CB_E5, "SET 4, L", 1);
  *(table_CB + 0xE6) = Operation.New(_CB_E6, "SET 4, (HL)", 1);
  *(table_CB + 0xE7) = Operation.New(_CB_E7, "SET 4, A", 1);
  *(table_CB + 0xE8) = Operation.New(_CB_E8, "SET 5, B", 1);
  *(table_CB + 0xE9) = Operation.New(_CB_E9, "SET 5, C", 1);
  *(table_CB + 0xEA) = Operation.New(_CB_EA, "SET 5, D", 1);
  *(table_CB + 0xEB) = Operation.New(_CB_EB, "SET 5, E", 1);
  *(table_CB + 0xEC) = Operation.New(_CB_EC, "SET 5, H", 1);
  *(table_CB + 0xED) = Operation.New(_CB_ED, "SET 5, L", 1);
  *(table_CB + 0xEE) = Operation.New(_CB_EE, "SET 5, (HL)", 1);
  *(table_CB + 0xEF) = Operation.New(_CB_EF, "SET 5, A", 1);

  *(table_CB + 0xF0) = Operation.New(_CB_F0, "SET 6, B", 1);
  *(table_CB + 0xF1) = Operation.New(_CB_F1, "SET 6, C", 1);
  *(table_CB + 0xF2) = Operation.New(_CB_F2, "SET 6, D", 1);
  *(table_CB + 0xF3) = Operation.New(_CB_F3, "SET 6, E", 1);
  *(table_CB + 0xF4) = Operation.New(_CB_F4, "SET 6, H", 1);
  *(table_CB + 0xF5) = Operation.New(_CB_F5, "SET 6, L", 1);
  *(table_CB + 0xF6) = Operation.New(_CB_F6, "SET 6, (HL)", 1);
  *(table_CB + 0xF7) = Operation.New(_CB_F7, "SET 6, A", 1);
  *(table_CB + 0xF8) = Operation.New(_CB_F8, "SET 7, B", 1);
  *(table_CB + 0xF9) = Operation.New(_CB_F9, "SET 7, C", 1);
  *(table_CB + 0xFA) = Operation.New(_CB_FA, "SET 7, D", 1);
  *(table_CB + 0xFB) = Operation.New(_CB_FB, "SET 7, E", 1);
  *(table_CB + 0xFC) = Operation.New(_CB_FC, "SET 7, H", 1);
  *(table_CB + 0xFD) = Operation.New(_CB_FD, "SET 7, L", 1);
  *(table_CB + 0xFE) = Operation.New(_CB_FE, "SET 7, (HL)", 1);
  *(table_CB + 0xFF) = Operation.New(_CB_FF, "SET 7, A", 1);
}

acquire();

def release() {
  libc.free(table as *uint8);
  libc.free(table_CB as *uint8);
}

libc.atexit(release);

def next(c: *cpu.CPU): Operation {
  let r: Operation;

  // let opcode = c.MMU.Read(c.PC);
  // c.PC += 1;
  //
  // c.Tick();
  let opcode = om.readNext8(c);

  // HACK: This really belongs in cpu.as but I can't think of a better
  //       place
  if c.HALT == -1 {
    c.PC -= 1;
    c.HALT = 0;
  }

  if opcode == 0xCB {
    opcode = om.readNext8(c);
    // opcode = c.MMU.Read(c.PC);
    // c.PC += 1;
    //
    // c.Tick();

    r = *(table_CB + opcode);
  } else {
    r = *(table + opcode);
  }

  if r.size == 0 {
    libc.printf("error: unknown opcode: $%02X\n", opcode);
    libc.exit(-1);
  }

  return r;
}

// For instructions which either read or write, but not both, the CPU makes
// the access on the last cycle.

// For instructions which read, modify, then
// write back, the CPU reads on the next-to-last cycle, and writes on the
// last cycle.

// 00 — NOP {1}
def _00(c: *cpu.CPU) {
  // Do nothing
}

// 01 nn nn — LD BC, u16 {3}
def _01(c: *cpu.CPU) {
  c.BC = om.readNext16(c);
}

// 02 — LD (BC), A {2}
def _02(c: *cpu.CPU) {
  om.write8(c, c.BC, *(c.A));
}

// 03 — INC BC {2}
def _03(c: *cpu.CPU) {
  c.BC += 1;
  c.Tick();
}

// 04 — INC B {1}
def _04(c: *cpu.CPU) {
  *(c.B) = om.inc8(c, *(c.B));
}

// 05 — DEC B {1}
def _05(c: *cpu.CPU) {
  *(c.B) = om.dec8(c, *(c.B));
}

// 06 nn — LD B, u8 {2}
def _06(c: *cpu.CPU) {
  *(c.B) = om.readNext8(c);
}

// 07 — RLCA {1}
def _07(c: *cpu.CPU) {
  *(c.A) = om.rotl8(c, *(c.A), false);
  om.flag_set(c, om.FLAG_Z, false);
}

// 08 nn nn — LD (u16), SP {5}
def _08(c: *cpu.CPU) {
  om.write16(c, om.readNext16(c), c.SP);
}

// 09 — ADD HL, BC {2}
def _09(c: *cpu.CPU) {
  c.HL = om.add16(c, c.HL, c.BC);
  c.Tick();
}

// 0A — LD A, (BC) {2}
def _0A(c: *cpu.CPU) {
  *(c.A) = om.read8(c, c.BC);
}

// 0B — DEC BC {2}
def _0B(c: *cpu.CPU) {
  c.BC -= 1;
  c.Tick();
}

// 0C — INC C {1}
def _0C(c: *cpu.CPU) {
  *(c.C) = om.inc8(c, *(c.C));
}

// 0D — DEC C {1}
def _0D(c: *cpu.CPU) {
  *(c.C) = om.dec8(c, *(c.C));
}

// 0E nn — LD C, u8 {2}
def _0E(c: *cpu.CPU) {
  *(c.C) = om.readNext8(c);
}

// 0F — RRCA {1}
def _0F(c: *cpu.CPU) {
  *(c.A) = om.rotr8(c, *(c.A), false);
  om.flag_set(c, om.FLAG_Z, false);
}

// 10 — STOP
def _10(c: *cpu.CPU) {
  libc.printf("warn: unsupported STOP\n");
}

// 11 nn nn — LD DE, u16 {3}
def _11(c: *cpu.CPU) {
  c.DE = om.readNext16(c);
}

// 12 — LD (DE), A {2}
def _12(c: *cpu.CPU) {
  om.write8(c, c.DE, *(c.A));
}

// 13 — INC DE {2}
def _13(c: *cpu.CPU) {
  c.DE += 1;
  c.Tick();
}

// 14 — INC D {1}
def _14(c: *cpu.CPU) {
  *(c.D) = om.inc8(c, *(c.D));
}

// 15 — DEC D {1}
def _15(c: *cpu.CPU) {
  *(c.D) = om.dec8(c, *(c.D));
}

// 16 nn — LD D, u8 {2}
def _16(c: *cpu.CPU) {
  *(c.D) = om.readNext8(c);
}

// 17 — RLA {1}
def _17(c: *cpu.CPU) {
  *(c.A) = om.rotl8(c, *(c.A), true);
  om.flag_set(c, om.FLAG_Z, false);
}

// 18 nn — JR i8 {3}
def _18(c: *cpu.CPU) {
  om.jr(c, om.readNext8(c));
}

// 19 — ADD HL, DE {2}
def _19(c: *cpu.CPU) {
  c.HL = om.add16(c, c.HL, c.DE);
  c.Tick();
}

// 1A — LD A, (DE) {2}
def _1A(c: *cpu.CPU) {
  *(c.A) = om.read8(c, c.DE);
}

// 1B — DEC DE {2}
def _1B(c: *cpu.CPU) {
  c.DE -= 1;
  c.Tick();
}

// 1C — INC E {1}
def _1C(c: *cpu.CPU) {
  *(c.E) = om.inc8(c, *(c.E));
}

// 1D — DEC E {1}
def _1D(c: *cpu.CPU) {
  *(c.E) = om.dec8(c, *(c.E));
}

// 1E nn — LD E, u8 {2}
def _1E(c: *cpu.CPU) {
  *(c.E) = om.readNext8(c);
}

// 1F — RRA {1}
def _1F(c: *cpu.CPU) {
  *(c.A) = om.rotr8(c, *(c.A), true);
  om.flag_set(c, om.FLAG_Z, false);
}

// 20 nn — JR NZ, i8 {3/2}
def _20(c: *cpu.CPU) {
  let i = om.readNext8(c);
  if not om.flag_get(c, om.FLAG_Z) {
    om.jr(c, i);
  }
}

// 21 nn nn — LD HL, u16 {3}
def _21(c: *cpu.CPU) {
  c.HL = om.readNext16(c);
}

// 22 — LDI (HL), A {2}
def _22(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.A));
  c.HL += 1;
}

// 23 — INC HL {2}
def _23(c: *cpu.CPU) {
  c.HL += 1;
  c.Tick();
}

// 24 — INC H {1}
def _24(c: *cpu.CPU) {
  *(c.H) = om.inc8(c, *(c.H));
}

// 25 — DEC H {1}
def _25(c: *cpu.CPU) {
  *(c.H) = om.dec8(c, *(c.H));
}

// 26 nn — LD H, u8 {2}
def _26(c: *cpu.CPU) {
  *(c.H) = om.readNext8(c);
}

// 27 — DAA {1}
def _27(c: *cpu.CPU) {
  // REF: http://stackoverflow.com/a/29990058

  // When this instruction is executed, the A register is BCD corrected
  // using the contents of the flags. The exact process is the following:
  // if the least significant four bits of A contain a non-BCD digit (i. e.
  // it is greater than 9) or the H flag is set, then $06 is added to the
  // register. Then the four most significant bits are checked. If this
  // more significant digit also happens to be greater than 9 or the C
  // flag is set, then $60 is added.

  // If the N flag is set, subtract instead of add.

  // If the lower 4 bits form a number greater than 9 or H is set,
  // add $06 to the accumulator

  let r = uint16(*(c.A));
  let correction: uint16 = if om.flag_get(c, om.FLAG_C) { 0x60; } else { 0x00; };

  if om.flag_get(c, om.FLAG_H) or ((not om.flag_get(c, om.FLAG_N)) and ((r & 0x0F) > 9)) {
    correction |= 0x06;
  }

  if om.flag_get(c, om.FLAG_C) or ((not om.flag_get(c, om.FLAG_N)) and (r > 0x99)) {
    correction |= 0x60;
  }

  if om.flag_get(c, om.FLAG_N) {
    r -= correction;
  } else {
    r += correction;
  }

  if ((correction << 2) & 0x100) != 0 {
    om.flag_set(c, om.FLAG_C, true);
  }

  // NOTE: Half-carry is always unset (unlike a Z-80)
  om.flag_set(c, om.FLAG_H, false);

  *(c.A) = uint8(r & 0xFF);

  om.flag_set(c, om.FLAG_Z, *(c.A) == 0);
}

// 28 nn — JR Z, i8 {3/2}
def _28(c: *cpu.CPU) {
  let i = om.readNext8(c);
  if om.flag_get(c, om.FLAG_Z) {
    om.jr(c, i);
  }
}

// 29 — ADD HL, HL {2}
def _29(c: *cpu.CPU) {
  c.HL = om.add16(c, c.HL, c.HL);
  c.Tick();
}

// 2A — LDI A, (HL) {2}
def _2A(c: *cpu.CPU) {
  *(c.A) = om.read8(c, c.HL);
  c.HL += 1;
}

// 2B — DEC HL {2}
def _2B(c: *cpu.CPU) {
  c.HL -= 1;
  c.Tick();
}

// 2C — INC L {1}
def _2C(c: *cpu.CPU) {
  *(c.L) = om.inc8(c, *(c.L));
}

// 2D — DEC L {1}
def _2D(c: *cpu.CPU) {
  *(c.L) = om.dec8(c, *(c.L));
}

// 2E nn — LD L, u8 {2}
def _2E(c: *cpu.CPU) {
  *(c.L) = om.readNext8(c);
}

// 2F — CPL {1}
def _2F(c: *cpu.CPU) {
  *(c.A) ^= 0xFF;

  om.flag_set(c, om.FLAG_N, true);
  om.flag_set(c, om.FLAG_H, true);
}

// 30 nn nn — JR NC, u16 {3/2}
def _30(c: *cpu.CPU) {
  let i = om.readNext8(c);
  if not om.flag_get(c, om.FLAG_C) {
    om.jr(c, i);
  }
}

// 31 nn nn — LD SP, u16 {3}
def _31(c: *cpu.CPU) {
  c.SP = om.readNext16(c);
}

// 32 — LDD (HL), A {2}
def _32(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.A));
  c.HL -= 1;
}

// 33 — INC SP {2}
def _33(c: *cpu.CPU) {
  c.SP += 1;
  c.Tick();
}

// 34 — INC (HL) {3}
def _34(c: *cpu.CPU) {
  om.write8(c, c.HL, om.inc8(c, om.read8(c, c.HL)));
}

// 35 — DEC (HL) {3}
def _35(c: *cpu.CPU) {
  om.write8(c, c.HL, om.dec8(c, om.read8(c, c.HL)));
}

// 36 nn — LD (HL), u8 {3}
def _36(c: *cpu.CPU) {
  om.write8(c, c.HL, om.readNext8(c));
}

// 37 — SCF {1}
def _37(c: *cpu.CPU) {
  om.flag_set(c, om.FLAG_C, true);
  om.flag_set(c, om.FLAG_H, false);
  om.flag_set(c, om.FLAG_N, false);
}

// 38 nn nn — JR C, u16 {3/2}
def _38(c: *cpu.CPU) {
  let i = om.readNext8(c);
  if om.flag_get(c, om.FLAG_C) {
    om.jr(c, i);
  }
}

// 39 — ADD HL, SP {2}
def _39(c: *cpu.CPU) {
  c.HL = om.add16(c, c.HL, c.SP);
  c.Tick();
}

// 3A — LDD A, (HL) {2}
def _3A(c: *cpu.CPU) {
  *(c.A) = om.read8(c, c.HL);
  c.HL -= 1;
}

// 3B — DEC SP {2}
def _3B(c: *cpu.CPU) {
  c.SP -= 1;
  c.Tick();
}

// 3C — INC A {1}
def _3C(c: *cpu.CPU) {
  *(c.A) = om.inc8(c, *(c.A));
}

// 3D — DEC A {1}
def _3D(c: *cpu.CPU) {
  *(c.A) = om.dec8(c, *(c.A));
}

// 3E nn — LD A, u8 {2}
def _3E(c: *cpu.CPU) {
  *(c.A) = om.readNext8(c);
}

// 3F — CCF {1}
def _3F(c: *cpu.CPU) {
  om.flag_set(c, om.FLAG_C, om.flag_geti(c, om.FLAG_C) ^ 1 != 0);
  om.flag_set(c, om.FLAG_H, false);
  om.flag_set(c, om.FLAG_N, false);
}

// 40 — LD B, B {1}
def _40(c: *cpu.CPU) {
  *(c.B) = *(c.B);
}

// 41 — LD B, C {1}
def _41(c: *cpu.CPU) {
  *(c.B) = *(c.C);
}

// 42 — LD B, D {1}
def _42(c: *cpu.CPU) {
  *(c.B) = *(c.D);
}

// 43 — LD B, E {1}
def _43(c: *cpu.CPU) {
  *(c.B) = *(c.E);
}

// 44 — LD B, H {1}
def _44(c: *cpu.CPU) {
  *(c.B) = *(c.H);
}

// 45 — LD B, L {1}
def _45(c: *cpu.CPU) {
  *(c.B) = *(c.L);
}

// 46 — LD B, (HL) {2}
def _46(c: *cpu.CPU) {
  *(c.B) = om.read8(c, c.HL);
}

// 47 — LD B, A {1}
def _47(c: *cpu.CPU) {
  *(c.B) = *(c.A);
}

// 48 — LD C, B {1}
def _48(c: *cpu.CPU) {
  *(c.C) = *(c.B);
}

// 49 — LD C, C {1}
def _49(c: *cpu.CPU) {
  *(c.C) = *(c.C);
}

// 4A — LD C, D {1}
def _4A(c: *cpu.CPU) {
  *(c.C) = *(c.D);
}

// 4B — LD C, E {1}
def _4B(c: *cpu.CPU) {
  *(c.C) = *(c.E);
}

// 4C — LD C, H {1}
def _4C(c: *cpu.CPU) {
  *(c.C) = *(c.H);
}

// 4D — LD C, L {1}
def _4D(c: *cpu.CPU) {
  *(c.C) = *(c.L);
}

// 4E — LD C, (HL) {2}
def _4E(c: *cpu.CPU) {
  *(c.C) = om.read8(c, c.HL);
}

// 4F — LD C, A {1}
def _4F(c: *cpu.CPU) {
  *(c.C) = *(c.A);
}

// 50 — LD D, B {1}
def _50(c: *cpu.CPU) {
  *(c.D) = *(c.B);
}

// 51 — LD D, C {1}
def _51(c: *cpu.CPU) {
  *(c.D) = *(c.C);
}

// 52 — LD D, D {1}
def _52(c: *cpu.CPU) {
  *(c.D) = *(c.D);
}

// 53 — LD D, E {1}
def _53(c: *cpu.CPU) {
  *(c.D) = *(c.E);
}

// 54 — LD D, H {1}
def _54(c: *cpu.CPU) {
  *(c.D) = *(c.H);
}

// 55 — LD D, L {1}
def _55(c: *cpu.CPU) {
  *(c.D) = *(c.L);
}

// 56 — LD D, (HL) {2}
def _56(c: *cpu.CPU) {
  *(c.D) = om.read8(c, c.HL);
}

// 57 — LD D, A {1}
def _57(c: *cpu.CPU) {
  *(c.D) = *(c.A);
}

// 58 — LD E, B {1}
def _58(c: *cpu.CPU) {
  *(c.E) = *(c.B);
}

// 59 — LD E, C {1}
def _59(c: *cpu.CPU) {
  *(c.E) = *(c.C);
}

// 5A — LD E, D {1}
def _5A(c: *cpu.CPU) {
  *(c.E) = *(c.D);
}

// 5B — LD E, E {1}
def _5B(c: *cpu.CPU) {
  *(c.E) = *(c.E);
}

// 5C — LD E, H {1}
def _5C(c: *cpu.CPU) {
  *(c.E) = *(c.H);
}

// 5D — LD E, L {1}
def _5D(c: *cpu.CPU) {
  *(c.E) = *(c.L);
}

// 5E — LD E, (HL) {2}
def _5E(c: *cpu.CPU) {
  *(c.E) = om.read8(c, c.HL);
}

// 5F — LD E, A {1}
def _5F(c: *cpu.CPU) {
  *(c.E) = *(c.A);
}

// 60 — LD H, B {1}
def _60(c: *cpu.CPU) {
  *(c.H) = *(c.B);
}

// 61 — LD H, C {1}
def _61(c: *cpu.CPU) {
  *(c.H) = *(c.C);
}

// 62 — LD H, D {1}
def _62(c: *cpu.CPU) {
  *(c.H) = *(c.D);
}

// 63 — LD H, E {1}
def _63(c: *cpu.CPU) {
  *(c.H) = *(c.E);
}

// 64 — LD H, H {1}
def _64(c: *cpu.CPU) {
  *(c.H) = *(c.H);
}

// 65 — LD H, L {1}
def _65(c: *cpu.CPU) {
  *(c.H) = *(c.L);
}

// 66 — LD H, (HL) {2}
def _66(c: *cpu.CPU) {
  *(c.H) = om.read8(c, c.HL);
}

// 67 — LD H, A {1}
def _67(c: *cpu.CPU) {
  *(c.H) = *(c.A);
}

// 68 — LD L, B {1}
def _68(c: *cpu.CPU) {
  *(c.L) = *(c.B);
}

// 69 — LD L, C {1}
def _69(c: *cpu.CPU) {
  *(c.L) = *(c.C);
}

// 6A — LD L, D {1}
def _6A(c: *cpu.CPU) {
  *(c.L) = *(c.D);
}

// 6B — LD L, E {1}
def _6B(c: *cpu.CPU) {
  *(c.L) = *(c.E);
}

// 6C — LD L, H {1}
def _6C(c: *cpu.CPU) {
  *(c.L) = *(c.H);
}

// 6D — LD L, L {1}
def _6D(c: *cpu.CPU) {
  *(c.L) = *(c.L);
}

// 6E — LD L, (HL) {2}
def _6E(c: *cpu.CPU) {
  *(c.L) = om.read8(c, c.HL);
}

// 6F — LD L, A {1}
def _6F(c: *cpu.CPU) {
  *(c.L) = *(c.A);
}

// 70 — LD (HL), B {2}
def _70(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.B));
}

// 71 — LD (HL), C {2}
def _71(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.C));
}

// 72 — LD (HL), D {2}
def _72(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.D));
}

// 73 — LD (HL), E {2}
def _73(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.E));
}

// 74 — LD (HL), H {2}
def _74(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.H));
}

// 75 — LD (HL), L {2}
def _75(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.L));
}

// 76 — HALT
def _76(c: *cpu.CPU) {
  // If IME is NOT enabled but IE/IF indicate there is a pending interrupt;
  // set HALT to a funny state that will cause us to 'replay' the next
  // opcode
  c.HALT = if (c.IME == 0) and (c.IE & c.IF & 0x1F) != 0 {
    -1;
  } else {
     1;
  };
}

// 77 — LD (HL), A {2}
def _77(c: *cpu.CPU) {
  om.write8(c, c.HL, *(c.A));
}

// 78 — LD A, B {1}
def _78(c: *cpu.CPU) {
  *(c.A) = *(c.B);
}

// 79 — LD A, C {1}
def _79(c: *cpu.CPU) {
  *(c.A) = *(c.C);
}

// 7A — LD A, D {1}
def _7A(c: *cpu.CPU) {
  *(c.A) = *(c.D);
}

// 7B — LD A, E {1}
def _7B(c: *cpu.CPU) {
  *(c.A) = *(c.E);
}

// 7C — LD A, H {1}
def _7C(c: *cpu.CPU) {
  *(c.A) = *(c.H);
}

// 7D — LD A, L {1}
def _7D(c: *cpu.CPU) {
  *(c.A) = *(c.L);
}

// 7E — LD A, (HL) {2}
def _7E(c: *cpu.CPU) {
  *(c.A) = om.read8(c, c.HL);
}

// 7F — LD A, A {1}
def _7F(c: *cpu.CPU) {
  *(c.A) = *(c.A);
}

// 80 — ADD A, B {1}
def _80(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), *(c.B));
}

// 81 — ADD A, C {1}
def _81(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), *(c.C));
}

// 82 — ADD A, D {1}
def _82(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), *(c.D));
}

// 83 — ADD A, E {1}
def _83(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), *(c.E));
}

// 84 — ADD A, H {1}
def _84(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), *(c.H));
}

// 85 — ADD A, L {1}
def _85(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), *(c.L));
}

// 86 — ADD A, (HL) {2}
def _86(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), om.read8(c, c.HL));
}

// 87 — ADD A, A {1}
def _87(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), *(c.A));
}

// 88 — ADC A, B {1}
def _88(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), *(c.B));
}

// 89 — ADC A, C {1}
def _89(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), *(c.C));
}

// 8A — ADC A, D {1}
def _8A(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), *(c.D));
}

// 8B — ADC A, E {1}
def _8B(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), *(c.E));
}

// 8C — ADC A, H {1}
def _8C(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), *(c.H));
}

// 8D — ADC A, L {1}
def _8D(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), *(c.L));
}

// 8E — ADC A, (HL) {2}
def _8E(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), om.read8(c, c.HL));
}

// 8F — ADC A, A {1}
def _8F(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), *(c.A));
}

// 90 — SUB A, B {1}
def _90(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), *(c.B));
}

// 91 — SUB A, C {1}
def _91(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), *(c.C));
}

// 92 — SUB A, D {1}
def _92(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), *(c.D));
}

// 93 — SUB A, E {1}
def _93(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), *(c.E));
}

// 94 — SUB A, H {1}
def _94(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), *(c.H));
}

// 95 — SUB A, L {1}
def _95(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), *(c.L));
}

// 96 — SUB A, (HL) {2}
def _96(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), om.read8(c, c.HL));
}

// 97 — SUB A, A {1}
def _97(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), *(c.A));
}

// 98 — SBC A, B {1}
def _98(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), *(c.B));
}

// 99 — SBC A, C {1}
def _99(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), *(c.C));
}

// 9A — SBC A, D {1}
def _9A(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), *(c.D));
}

// 9B — SBC A, E {1}
def _9B(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), *(c.E));
}

// 9C — SBC A, H {1}
def _9C(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), *(c.H));
}

// 9D — SBC A, L {1}
def _9D(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), *(c.L));
}

// 9E — SBC A, (HL) {2}
def _9E(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), om.read8(c, c.HL));
}

// 9F — SBC A, A {1}
def _9F(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), *(c.A));
}

// A0 — AND A, B {1}
def _A0(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), *(c.B));
}

// A1 — AND A, C {1}
def _A1(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), *(c.C));
}

// A2 — AND A, D {1}
def _A2(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), *(c.D));
}

// A3 — AND A, E {1}
def _A3(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), *(c.E));
}

// A4 — AND A, H {1}
def _A4(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), *(c.H));
}

// A5 — AND A, L {1}
def _A5(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), *(c.L));
}

// A6 — AND A, (HL) {2}
def _A6(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), om.read8(c, c.HL));
}

// A7 — AND A, A {1}
def _A7(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), *(c.A));
}

// A8 — XOR A, B {1}
def _A8(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), *(c.B));
}

// A9 — XOR A, C {1}
def _A9(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), *(c.C));
}

// AA — XOR A, D {1}
def _AA(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), *(c.D));
}

// AB — XOR A, E {1}
def _AB(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), *(c.E));
}

// AC — XOR A, H {1}
def _AC(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), *(c.H));
}

// AD — XOR A, L {1}
def _AD(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), *(c.L));
}

// AE — XOR A, (HL) {2}
def _AE(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), om.read8(c, c.HL));
}

// AF — XOR A, A {1}
def _AF(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), *(c.A));
}

// B0 — OR A, B {1}
def _B0(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), *(c.B));
}

// B1 — OR A, C {1}
def _B1(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), *(c.C));
}

// B2 — OR A, D {1}
def _B2(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), *(c.D));
}

// B3 — OR A, E {1}
def _B3(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), *(c.E));
}

// B4 — OR A, H {1}
def _B4(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), *(c.H));
}

// B5 — OR A, L {1}
def _B5(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), *(c.L));
}

// B6 — OR A, (HL) {2}
def _B6(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), om.read8(c, c.HL));
}

// B7 — OR A, A {1}
def _B7(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), *(c.A));
}

// B8 — CP A, B {1}
def _B8(c: *cpu.CPU) {
  om.sub8(c, *(c.A), *(c.B));
}

// B9 — CP A, C {1}
def _B9(c: *cpu.CPU) {
  om.sub8(c, *(c.A), *(c.C));
}

// BA — CP A, D {1}
def _BA(c: *cpu.CPU) {
  om.sub8(c, *(c.A), *(c.D));
}

// BB — CP A, E {1}
def _BB(c: *cpu.CPU) {
  om.sub8(c, *(c.A), *(c.E));
}

// BC — CP A, H {1}
def _BC(c: *cpu.CPU) {
  om.sub8(c, *(c.A), *(c.H));
}

// BD — CP A, L {1}
def _BD(c: *cpu.CPU) {
  om.sub8(c, *(c.A), *(c.L));
}

// BE — CP A, (HL) {2}
def _BE(c: *cpu.CPU) {
  om.sub8(c, *(c.A), om.read8(c, c.HL));
}

// BF — CP A, A {1}
def _BF(c: *cpu.CPU) {
  om.sub8(c, *(c.A), *(c.A));
}

// C0 — RET NZ {5/2}
def _C0(c: *cpu.CPU) {
  c.Tick();
  if not om.flag_get(c, om.FLAG_Z) {
    om.ret(c);
  }
}

// C1 — POP BC {3}
def _C1(c: *cpu.CPU) {
  om.pop16(c, &c.BC);
}

// C2 nn nn — JP NZ, u16 {4/3}
def _C2(c: *cpu.CPU) {
  let address = om.readNext16(c);
  if not om.flag_get(c, om.FLAG_Z) {
    om.jp(c, address, true);
  }
}

// C3 nn nn — JP u16 {4}
def _C3(c: *cpu.CPU) {
  om.jp(c, om.readNext16(c), true);
}

// C4 nn nn — CALL NZ, u16 {6/3}
def _C4(c: *cpu.CPU) {
  let address = om.readNext16(c);
  if not om.flag_get(c, om.FLAG_Z) {
    om.call(c, address);
  }
}

// C5 — PUSH BC {4}
def _C5(c: *cpu.CPU) {
  c.Tick();
  om.push16(c, &c.BC);
}

// C6 nn — ADD A, u8 {2}
def _C6(c: *cpu.CPU) {
  *(c.A) = om.add8(c, *(c.A), om.readNext8(c));
}

// C7 — RST $00 {4}
def _C7(c: *cpu.CPU) {
  om.call(c, 0x00);
}

// C8 — RET Z {5/2}
def _C8(c: *cpu.CPU) {
  c.Tick();
  if om.flag_get(c, om.FLAG_Z) {
    om.ret(c);
  }
}

// C9 — RET {4}
def _C9(c: *cpu.CPU) {
  om.ret(c);
}

// CA nn nn — JP Z, u16 {4/3}
def _CA(c: *cpu.CPU) {
  let address = om.readNext16(c);
  if om.flag_get(c, om.FLAG_Z) {
    om.jp(c, address, true);
  }
}

// CC nn nn — CALL Z, u16 {6/3}
def _CC(c: *cpu.CPU) {
  let address = om.readNext16(c);
  if om.flag_get(c, om.FLAG_Z) {
    om.call(c, address);
  }
}

// CD nn nn — CALL u16 {6}
def _CD(c: *cpu.CPU) {
  om.call(c, om.readNext16(c));
}

// CE nn — ADC A, u8 {2}
def _CE(c: *cpu.CPU) {
  *(c.A) = om.adc8(c, *(c.A), om.readNext8(c));
}

// CF — RST $08 {4}
def _CF(c: *cpu.CPU) {
  om.call(c, 0x08);
}

// D0 — RET NC {5/2}
def _D0(c: *cpu.CPU) {
  c.Tick();
  if not om.flag_get(c, om.FLAG_C) {
    om.ret(c);
  }
}

// D1 — POP DE {3}
def _D1(c: *cpu.CPU) {
  om.pop16(c, &c.DE);
}

// D2 nn nn — JP NC, u16 {4/3}
def _D2(c: *cpu.CPU) {
  let address = om.readNext16(c);
  if not om.flag_get(c, om.FLAG_C) {
    om.jp(c, address, true);
  }
}

// D4 nn nn — CALL NC, u16 {6/3}
def _D4(c: *cpu.CPU) {
  let address = om.readNext16(c);
  if not om.flag_get(c, om.FLAG_C) {
    om.call(c, address);
  }
}

// D5 — PUSH DE {4}
def _D5(c: *cpu.CPU) {
  c.Tick();
  om.push16(c, &c.DE);
}

// D6 nn — SUB A, u8 {2}
def _D6(c: *cpu.CPU) {
  *(c.A) = om.sub8(c, *(c.A), om.readNext8(c));
}

// D7 — RST $10 {4}
def _D7(c: *cpu.CPU) {
  om.call(c, 0x10);
}

// D8 — RET C {5/2}
def _D8(c: *cpu.CPU) {
  c.Tick();
  if om.flag_get(c, om.FLAG_C) {
    om.ret(c);
  }
}

// D9 — RETI {4}
def _D9(c: *cpu.CPU) {
  om.ret(c);
  c.IME = 1;
}

// DA nn nn — JP C, u16 {4/3}
def _DA(c: *cpu.CPU) {
  let address = om.readNext16(c);
  if om.flag_get(c, om.FLAG_C) {
    om.jp(c, address, true);
  }
}

// DC nn nn — CALL C, u16 {6/3}
def _DC(c: *cpu.CPU) {
  let address = om.readNext16(c);
  // libc.printf("\t-> %04X\n", address);
  if om.flag_get(c, om.FLAG_C) {
    om.call(c, address);
  }
}

// DE nn — SBC A, u8 {2}
def _DE(c: *cpu.CPU) {
  *(c.A) = om.sbc8(c, *(c.A), om.readNext8(c));
}

// DF — RST $18 {4}
def _DF(c: *cpu.CPU) {
  om.call(c, 0x18);
}

// E0 — LD ($FF00 + n), A {3}
def _E0(c: *cpu.CPU) {
  om.write8(c, 0xFF00 + uint16(om.readNext8(c)), *(c.A));
}

// E1 — POP HL {3}
def _E1(c: *cpu.CPU) {
  om.pop16(c, &c.HL);
}

// E2 — LD ($FF00 + C), A {2}
def _E2(c: *cpu.CPU) {
  om.write8(c, 0xFF00 + uint16(*(c.C)), *(c.A));
}

// E5 — PUSH HL {4}
def _E5(c: *cpu.CPU) {
  c.Tick();
  om.push16(c, &c.HL);
}

// E6 nn — AND A, u8 {2}
def _E6(c: *cpu.CPU) {
  *(c.A) = om.and8(c, *(c.A), om.readNext8(c));
}

// E7 — RST $20 {4}
def _E7(c: *cpu.CPU) {
  om.call(c, 0x20);
}

// E8 nn — ADD SP, i8 {4}
def _E8(c: *cpu.CPU) {
  // M = 0: instruction decoding
  // M = 1: memory access for e
  // M = 2: internal delay
  // M = 3: internal delay

  let n = int16(int8(om.readNext8(c)));
  let r = uint16(int16(c.SP) + n);

  om.flag_set(c, om.FLAG_C, (r & 0xFF) < (c.SP & 0xFF));
  om.flag_set(c, om.FLAG_H, (r & 0xF) < (c.SP & 0xF));
  om.flag_set(c, om.FLAG_Z, false);
  om.flag_set(c, om.FLAG_N, false);

  c.SP = r;
  c.Tick();
  c.Tick();
}

// E9 — JP HL {1}
def _E9(c: *cpu.CPU) {
  om.jp(c, c.HL, false);
}

// EA nn nn — LD (u16), A {4}
def _EA(c: *cpu.CPU) {
  om.write8(c, om.readNext16(c), *(c.A));
}

// EE nn — XOR A, u8 {2}
def _EE(c: *cpu.CPU) {
  *(c.A) = om.xor8(c, *(c.A), om.readNext8(c));
}

// EF — RST $28 {4}
def _EF(c: *cpu.CPU) {
  om.call(c, 0x28);
}

// F0 — LD A, ($FF00 + n) {3}
def _F0(c: *cpu.CPU) {
  *(c.A) = om.read8(c, 0xFF00 + uint16(om.readNext8(c)));
}

// F1 — POP AF {3}
def _F1(c: *cpu.CPU) {
  om.pop16(c, &c.AF);

  // NOTE: The F register can only ever have the top 4 bits set
  *(c.F) &= 0xF0;
}

// F2 — LD A, ($FF00 + C) {2}
def _F2(c: *cpu.CPU) {
  *(c.A) = om.read8(c, 0xFF00 + uint16(*(c.C)));
}

// F3 — DI {1}
def _F3(c: *cpu.CPU) {
  c.IME = 0;
}

// F5 — PUSH AF {4}
def _F5(c: *cpu.CPU) {
  c.Tick();
  om.push16(c, &c.AF);
}

// F6 nn — OR A, u8 {2}
def _F6(c: *cpu.CPU) {
  *(c.A) = om.or8(c, *(c.A), om.readNext8(c));
}

// F7 — RST $30 {4}
def _F7(c: *cpu.CPU) {
  om.call(c, 0x30);
}

// F8 nn — LD HL, SP + i8 {3}
def _F8(c: *cpu.CPU) {
  // M = 0: instruction decoding
  // M = 1: memory access for e
  // M = 2: internal delay

  let n = int16(int8(om.readNext8(c)));
  let r = uint16(int16(c.SP) + n);

  om.flag_set(c, om.FLAG_C, (r & 0xFF) < (c.SP & 0xFF));
  om.flag_set(c, om.FLAG_H, (r & 0xF) < (c.SP & 0xF));
  om.flag_set(c, om.FLAG_Z, false);
  om.flag_set(c, om.FLAG_N, false);

  c.HL = r;
  c.Tick();
}

// F9 — LD SP, HL {2}
def _F9(c: *cpu.CPU) {
  c.SP = c.HL;
  c.Tick();
}

// FA nn nn — LD A, (u16) {4}
def _FA(c: *cpu.CPU) {
  *(c.A) = om.read8(c, om.readNext16(c));
}

// FB — EI {1}
def _FB(c: *cpu.CPU) {
  // -1 - PENDING (will set to 1 just before next instruction
  //               but after the interrupt check)
  c.IME = -1;
}

// FE nn — CP u8 {2}
def _FE(c: *cpu.CPU) {
  om.sub8(c, *(c.A), om.readNext8(c));
}

// FF — RST $38 {4}
def _FF(c: *cpu.CPU) {
  om.call(c, 0x38);
}

// CB 00 — RLC B {2}
def _CB_00(c: *cpu.CPU) {
  *(c.B) = om.rotl8(c, *(c.B), false);
}

// CB 01 — RLC C {2}
def _CB_01(c: *cpu.CPU) {
  *(c.C) = om.rotl8(c, *(c.C), false);
}

// CB 02 — RLC D {2}
def _CB_02(c: *cpu.CPU) {
  *(c.D) = om.rotl8(c, *(c.D), false);
}

// CB 03 — RLC E {2}
def _CB_03(c: *cpu.CPU) {
  *(c.E) = om.rotl8(c, *(c.E), false);
}

// CB 04 — RLC H {2}
def _CB_04(c: *cpu.CPU) {
  *(c.H) = om.rotl8(c, *(c.H), false);
}

// CB 05 — RLC L {2}
def _CB_05(c: *cpu.CPU) {
  *(c.L) = om.rotl8(c, *(c.L), false);
}

// CB 06 — RLC (HL) {3}
def _CB_06(c: *cpu.CPU) {
  om.write8(c, c.HL, om.rotl8(c, om.read8(c, c.HL), false));
}

// CB 07 — RLC A {2}
def _CB_07(c: *cpu.CPU) {
  *(c.A) = om.rotl8(c, *(c.A), false);
}

// CB 08 — RRC B {2}
def _CB_08(c: *cpu.CPU) {
  *(c.B) = om.rotr8(c, *(c.B), false);
}

// CB 09 — RRC C {2}
def _CB_09(c: *cpu.CPU) {
  *(c.C) = om.rotr8(c, *(c.C), false);
}

// CB 0A — RRC D {2}
def _CB_0A(c: *cpu.CPU) {
  *(c.D) = om.rotr8(c, *(c.D), false);
}

// CB 0B — RRC E {2}
def _CB_0B(c: *cpu.CPU) {
  *(c.E) = om.rotr8(c, *(c.E), false);
}

// CB 0C — RRC H {2}
def _CB_0C(c: *cpu.CPU) {
  *(c.H) = om.rotr8(c, *(c.H), false);
}

// CB 0D — RRC L {2}
def _CB_0D(c: *cpu.CPU) {
  *(c.L) = om.rotr8(c, *(c.L), false);
}

// CB 0E — RRC (HL) {3}
def _CB_0E(c: *cpu.CPU) {
  om.write8(c, c.HL, om.rotr8(c, om.read8(c, c.HL), false));
}

// CB 0F — RRC A {2}
def _CB_0F(c: *cpu.CPU) {
  *(c.A) = om.rotr8(c, *(c.A), false);
}

// CB 10 — RL B {2}
def _CB_10(c: *cpu.CPU) {
  *(c.B) = om.rotl8(c, *(c.B), true);
}

// CB 11 — RL C {2}
def _CB_11(c: *cpu.CPU) {
  *(c.C) = om.rotl8(c, *(c.C), true);
}

// CB 12 — RL D {2}
def _CB_12(c: *cpu.CPU) {
  *(c.D) = om.rotl8(c, *(c.D), true);
}

// CB 13 — RL E {2}
def _CB_13(c: *cpu.CPU) {
  *(c.E) = om.rotl8(c, *(c.E), true);
}

// CB 14 — RL H {2}
def _CB_14(c: *cpu.CPU) {
  *(c.H) = om.rotl8(c, *(c.H), true);
}

// CB 15 — RL L {2}
def _CB_15(c: *cpu.CPU) {
  *(c.L) = om.rotl8(c, *(c.L), true);
}

// CB 16 — RL (HL) {3}
def _CB_16(c: *cpu.CPU) {
  om.write8(c, c.HL, om.rotl8(c, om.read8(c, c.HL), true));
}

// CB 17 — RL A {2}
def _CB_17(c: *cpu.CPU) {
  *(c.A) = om.rotl8(c, *(c.A), true);
}

// CB 18 — RR B {2}
def _CB_18(c: *cpu.CPU) {
  *(c.B) = om.rotr8(c, *(c.B), true);
}

// CB 19 — RR C {2}
def _CB_19(c: *cpu.CPU) {
  *(c.C) = om.rotr8(c, *(c.C), true);
}

// CB 1A — RR D {2}
def _CB_1A(c: *cpu.CPU) {
  *(c.D) = om.rotr8(c, *(c.D), true);
}

// CB 1B — RR E {2}
def _CB_1B(c: *cpu.CPU) {
  *(c.E) = om.rotr8(c, *(c.E), true);
}

// CB 1C — RR H {2}
def _CB_1C(c: *cpu.CPU) {
  *(c.H) = om.rotr8(c, *(c.H), true);
}

// CB 1D — RR L {2}
def _CB_1D(c: *cpu.CPU) {
  *(c.L) = om.rotr8(c, *(c.L), true);
}

// CB 1E — RR (HL) {3}
def _CB_1E(c: *cpu.CPU) {
  om.write8(c, c.HL, om.rotr8(c, om.read8(c, c.HL), true));
}

// CB 1F — RR A {2}
def _CB_1F(c: *cpu.CPU) {
  *(c.A) = om.rotr8(c, *(c.A), true);
}

// CB 20 — SLA B {2}
def _CB_20(c: *cpu.CPU) {
  *(c.B) = om.shl(c, *(c.B));
}

// CB 21 — SLA C {2}
def _CB_21(c: *cpu.CPU) {
  *(c.C) = om.shl(c, *(c.C));
}

// CB 22 — SLA D {2}
def _CB_22(c: *cpu.CPU) {
  *(c.D) = om.shl(c, *(c.D));
}

// CB 23 — SLA E {2}
def _CB_23(c: *cpu.CPU) {
  *(c.E) = om.shl(c, *(c.E));
}

// CB 24 — SLA H {2}
def _CB_24(c: *cpu.CPU) {
  *(c.H) = om.shl(c, *(c.H));
}

// CB 25 — SLA L {2}
def _CB_25(c: *cpu.CPU) {
  *(c.L) = om.shl(c, *(c.L));
}

// CB 26 — SLA (HL) {3}
def _CB_26(c: *cpu.CPU) {
  om.write8(c, c.HL, om.shl(c, om.read8(c, c.HL)));
}

// CB 27 — SLA A {2}
def _CB_27(c: *cpu.CPU) {
  *(c.A) = om.shl(c, *(c.A));
}

// CB 28 — SRA B {2}
def _CB_28(c: *cpu.CPU) {
  *(c.B) = om.shr(c, *(c.B), true);
}

// CB 29 — SRA C {2}
def _CB_29(c: *cpu.CPU) {
  *(c.C) = om.shr(c, *(c.C), true);
}

// CB 2A — SRA D {2}
def _CB_2A(c: *cpu.CPU) {
  *(c.D) = om.shr(c, *(c.D), true);
}

// CB 2B — SRA E {2}
def _CB_2B(c: *cpu.CPU) {
  *(c.E) = om.shr(c, *(c.E), true);
}

// CB 2C — SRA H {2}
def _CB_2C(c: *cpu.CPU) {
  *(c.H) = om.shr(c, *(c.H), true);
}

// CB 2D — SRA L {2}
def _CB_2D(c: *cpu.CPU) {
  *(c.L) = om.shr(c, *(c.L), true);
}

// CB 2E — SRA (HL) {3}
def _CB_2E(c: *cpu.CPU) {
  om.write8(c, c.HL, om.shr(c, om.read8(c, c.HL), true));
}

// CB 2F — SRA A {2}
def _CB_2F(c: *cpu.CPU) {
  *(c.A) = om.shr(c, *(c.A), true);
}

// CB 30 — SWAP B {2}
def _CB_30(c: *cpu.CPU) {
  *(c.B) = om.swap8(c, *(c.B));
}

// CB 31 — SWAP C {2}
def _CB_31(c: *cpu.CPU) {
  *(c.C) = om.swap8(c, *(c.C));
}

// CB 32 — SWAP D {2}
def _CB_32(c: *cpu.CPU) {
  *(c.D) = om.swap8(c, *(c.D));
}

// CB 33 — SWAP E {2}
def _CB_33(c: *cpu.CPU) {
  *(c.E) = om.swap8(c, *(c.E));
}

// CB 34 — SWAP H {2}
def _CB_34(c: *cpu.CPU) {
  *(c.H) = om.swap8(c, *(c.H));
}

// CB 35 — SWAP L {2}
def _CB_35(c: *cpu.CPU) {
  *(c.L) = om.swap8(c, *(c.L));
}

// CB 36 — SWAP (HL) {3}
def _CB_36(c: *cpu.CPU) {
  om.write8(c, c.HL, om.swap8(c, om.read8(c, c.HL)));
}

// CB 37 — SWAP A {2}
def _CB_37(c: *cpu.CPU) {
  *(c.A) = om.swap8(c, *(c.A));
}

// CB 38 — SRL B {2}
def _CB_38(c: *cpu.CPU) {
  *(c.B) = om.shr(c, *(c.B), false);
}

// CB 39 — SRL C {2}
def _CB_39(c: *cpu.CPU) {
  *(c.C) = om.shr(c, *(c.C), false);
}

// CB 3A — SRL D {2}
def _CB_3A(c: *cpu.CPU) {
  *(c.D) = om.shr(c, *(c.D), false);
}

// CB 3B — SRL E {2}
def _CB_3B(c: *cpu.CPU) {
  *(c.E) = om.shr(c, *(c.E), false);
}

// CB 3C — SRL H {2}
def _CB_3C(c: *cpu.CPU) {
  *(c.H) = om.shr(c, *(c.H), false);
}

// CB 3D — SRL L {2}
def _CB_3D(c: *cpu.CPU) {
  *(c.L) = om.shr(c, *(c.L), false);
}

// CB 3E — SRL (HL) {3}
def _CB_3E(c: *cpu.CPU) {
  om.write8(c, c.HL, om.shr(c, om.read8(c, c.HL), false));
}

// CB 3F — SRL A {2}
def _CB_3F(c: *cpu.CPU) {
  *(c.A) = om.shr(c, *(c.A), false);
}

// CB 40 — BIT 0, B {2}
def _CB_40(c: *cpu.CPU) {
  om.bit8(c, *(c.B), 0);
}

// CB 41 — BIT 0, C {2}
def _CB_41(c: *cpu.CPU) {
  om.bit8(c, *(c.C), 0);
}

// CB 42 — BIT 0, D {2}
def _CB_42(c: *cpu.CPU) {
  om.bit8(c, *(c.D), 0);
}

// CB 43 — BIT 0, E {2}
def _CB_43(c: *cpu.CPU) {
  om.bit8(c, *(c.E), 0);
}

// CB 44 — BIT 0, H {2}
def _CB_44(c: *cpu.CPU) {
  om.bit8(c, *(c.H), 0);
}

// CB 45 — BIT 0, L {2}
def _CB_45(c: *cpu.CPU) {
  om.bit8(c, *(c.L), 0);
}

// CB 46 — BIT 0, (HL) {3}
def _CB_46(c: *cpu.CPU) {
  om.bit8(c, om.read8(c, c.HL), 0);
}

// CB 47 — BIT 0, A {2}
def _CB_47(c: *cpu.CPU) {
  om.bit8(c, *(c.A), 0);
}

// CB 48 — BIT 1, B {2}
def _CB_48(c: *cpu.CPU) {
  om.bit8(c, *(c.B), 1);
}

// CB 49 — BIT 1, C {2}
def _CB_49(c: *cpu.CPU) {
  om.bit8(c, *(c.C), 1);
}

// CB 4A — BIT 1, D {2}
def _CB_4A(c: *cpu.CPU) {
  om.bit8(c, *(c.D), 1);
}

// CB 4B — BIT 1, E {2}
def _CB_4B(c: *cpu.CPU) {
  om.bit8(c, *(c.E), 1);
}

// CB 4C — BIT 1, H {2}
def _CB_4C(c: *cpu.CPU) {
  om.bit8(c, *(c.H), 1);
}

// CB 4D — BIT 1, L {2}
def _CB_4D(c: *cpu.CPU) {
  om.bit8(c, *(c.L), 1);
}

// CB 4E — BIT 1, (HL) {3}
def _CB_4E(c: *cpu.CPU) {
  om.bit8(c, om.read8(c, c.HL), 1);
}

// CB 4F — BIT 1, A {2}
def _CB_4F(c: *cpu.CPU) {
  om.bit8(c, *(c.A), 1);
}

// CB 50 — BIT 2, B {2}
def _CB_50(c: *cpu.CPU) {
  om.bit8(c, *(c.B), 2);
}

// CB 51 — BIT 2, C {2}
def _CB_51(c: *cpu.CPU) {
  om.bit8(c, *(c.C), 2);
}

// CB 52 — BIT 2, D {2}
def _CB_52(c: *cpu.CPU) {
  om.bit8(c, *(c.D), 2);
}

// CB 53 — BIT 2, E {2}
def _CB_53(c: *cpu.CPU) {
  om.bit8(c, *(c.E), 2);
}

// CB 54 — BIT 2, H {2}
def _CB_54(c: *cpu.CPU) {
  om.bit8(c, *(c.H), 2);
}

// CB 55 — BIT 2, L {2}
def _CB_55(c: *cpu.CPU) {
  om.bit8(c, *(c.L), 2);
}

// CB 56 — BIT 2, (HL) {3}
def _CB_56(c: *cpu.CPU) {
  om.bit8(c, om.read8(c, c.HL), 2);
}

// CB 57 — BIT 2, A {2}
def _CB_57(c: *cpu.CPU) {
  om.bit8(c, *(c.A), 2);
}

// CB 58 — BIT 3, B {2}
def _CB_58(c: *cpu.CPU) {
  om.bit8(c, *(c.B), 3);
}

// CB 59 — BIT 3, C {2}
def _CB_59(c: *cpu.CPU) {
  om.bit8(c, *(c.C), 3);
}

// CB 5A — BIT 3, D {2}
def _CB_5A(c: *cpu.CPU) {
  om.bit8(c, *(c.D), 3);
}

// CB 5B — BIT 3, E {2}
def _CB_5B(c: *cpu.CPU) {
  om.bit8(c, *(c.E), 3);
}

// CB 5C — BIT 3, H {2}
def _CB_5C(c: *cpu.CPU) {
  om.bit8(c, *(c.H), 3);
}

// CB 5D — BIT 3, L {2}
def _CB_5D(c: *cpu.CPU) {
  om.bit8(c, *(c.L), 3);
}

// CB 5E — BIT 3, (HL) {3}
def _CB_5E(c: *cpu.CPU) {
  om.bit8(c, om.read8(c, c.HL), 3);
}

// CB 5F — BIT 3, A {2}
def _CB_5F(c: *cpu.CPU) {
  om.bit8(c, *(c.A), 3);
}

// CB 60 — BIT 4, B {2}
def _CB_60(c: *cpu.CPU) {
  om.bit8(c, *(c.B), 4);
}

// CB 61 — BIT 4, C {2}
def _CB_61(c: *cpu.CPU) {
  om.bit8(c, *(c.C), 4);
}

// CB 62 — BIT 4, D {2}
def _CB_62(c: *cpu.CPU) {
  om.bit8(c, *(c.D), 4);
}

// CB 63 — BIT 4, E {2}
def _CB_63(c: *cpu.CPU) {
  om.bit8(c, *(c.E), 4);
}

// CB 64 — BIT 4, H {2}
def _CB_64(c: *cpu.CPU) {
  om.bit8(c, *(c.H), 4);
}

// CB 65 — BIT 4, L {2}
def _CB_65(c: *cpu.CPU) {
  om.bit8(c, *(c.L), 4);
}

// CB 66 — BIT 4, (HL) {3}
def _CB_66(c: *cpu.CPU) {
  om.bit8(c, om.read8(c, c.HL), 4);
}

// CB 67 — BIT 4, A {2}
def _CB_67(c: *cpu.CPU) {
  om.bit8(c, *(c.A), 4);
}

// CB 68 — BIT 5, B {2}
def _CB_68(c: *cpu.CPU) {
  om.bit8(c, *(c.B), 5);
}

// CB 69 — BIT 5, C {2}
def _CB_69(c: *cpu.CPU) {
  om.bit8(c, *(c.C), 5);
}

// CB 6A — BIT 5, D {2}
def _CB_6A(c: *cpu.CPU) {
  om.bit8(c, *(c.D), 5);
}

// CB 6B — BIT 5, E {2}
def _CB_6B(c: *cpu.CPU) {
  om.bit8(c, *(c.E), 5);
}

// CB 6C — BIT 5, H {2}
def _CB_6C(c: *cpu.CPU) {
  om.bit8(c, *(c.H), 5);
}

// CB 6D — BIT 5, L {2}
def _CB_6D(c: *cpu.CPU) {
  om.bit8(c, *(c.L), 5);
}

// CB 6E — BIT 5, (HL) {2}
def _CB_6E(c: *cpu.CPU) {
  om.bit8(c, om.read8(c, c.HL), 5);
}

// CB 6F — BIT 5, A {2}
def _CB_6F(c: *cpu.CPU) {
  om.bit8(c, *(c.A), 5);
}

// CB 70 — BIT 6, B {2}
def _CB_70(c: *cpu.CPU) {
  om.bit8(c, *(c.B), 6);
}

// CB 71 — BIT 6, C {2}
def _CB_71(c: *cpu.CPU) {
  om.bit8(c, *(c.C), 6);
}

// CB 72 — BIT 6, D {2}
def _CB_72(c: *cpu.CPU) {
  om.bit8(c, *(c.D), 6);
}

// CB 73 — BIT 6, E {2}
def _CB_73(c: *cpu.CPU) {
  om.bit8(c, *(c.E), 6);
}

// CB 74 — BIT 6, H {2}
def _CB_74(c: *cpu.CPU) {
  om.bit8(c, *(c.H), 6);
}

// CB 75 — BIT 6, L {2}
def _CB_75(c: *cpu.CPU) {
  om.bit8(c, *(c.L), 6);
}

// CB 76 — BIT 6, (HL) {3}
def _CB_76(c: *cpu.CPU) {
  om.bit8(c, om.read8(c, c.HL), 6);
}

// CB 77 — BIT 6, A {2}
def _CB_77(c: *cpu.CPU) {
  om.bit8(c, *(c.A), 6);
}

// CB 78 — BIT 7, B {2}
def _CB_78(c: *cpu.CPU) {
  om.bit8(c, *(c.B), 7);
}

// CB 79 — BIT 7, C {2}
def _CB_79(c: *cpu.CPU) {
  om.bit8(c, *(c.C), 7);
}

// CB 7A — BIT 7, D {2}
def _CB_7A(c: *cpu.CPU) {
  om.bit8(c, *(c.D), 7);
}

// CB 7B — BIT 7, E {2}
def _CB_7B(c: *cpu.CPU) {
  om.bit8(c, *(c.E), 7);
}

// CB 7C — BIT 7, H {2}
def _CB_7C(c: *cpu.CPU) {
  om.bit8(c, *(c.H), 7);
}

// CB 7D — BIT 7, L {2}
def _CB_7D(c: *cpu.CPU) {
  om.bit8(c, *(c.L), 7);
}

// CB 7E — BIT 7, (HL) {3}
def _CB_7E(c: *cpu.CPU) {
  om.bit8(c, om.read8(c, c.HL), 7);
}

// CB 7F — BIT 7, A {2}
def _CB_7F(c: *cpu.CPU) {
  om.bit8(c, *(c.A), 7);
}

// CB 80 — RES 0, B {2}
def _CB_80(c: *cpu.CPU) {
  *(c.B) = om.res8(c, *(c.B), 0);
}

// CB 81 — RES 0, C {2}
def _CB_81(c: *cpu.CPU) {
  *(c.C) = om.res8(c, *(c.C), 0);
}

// CB 82 — RES 0, D {2}
def _CB_82(c: *cpu.CPU) {
  *(c.D) = om.res8(c, *(c.D), 0);
}

// CB 83 — RES 0, E {2}
def _CB_83(c: *cpu.CPU) {
  *(c.E) = om.res8(c, *(c.E), 0);
}

// CB 84 — RES 0, H {2}
def _CB_84(c: *cpu.CPU) {
  *(c.H) = om.res8(c, *(c.H), 0);
}

// CB 85 — RES 0, L {2}
def _CB_85(c: *cpu.CPU) {
  *(c.L) = om.res8(c, *(c.L), 0);
}

// CB 86 — RES 0, (HL) {3}
def _CB_86(c: *cpu.CPU) {
  om.write8(c, c.HL, om.res8(c, om.read8(c, c.HL), 0));
}

// CB 87 — RES 0, A {2}
def _CB_87(c: *cpu.CPU) {
  *(c.A) = om.res8(c, *(c.A), 0);
}

// CB 88 — RES 1, B {2}
def _CB_88(c: *cpu.CPU) {
  *(c.B) = om.res8(c, *(c.B), 1);
}

// CB 89 — RES 1, C {2}
def _CB_89(c: *cpu.CPU) {
  *(c.C) = om.res8(c, *(c.C), 1);
}

// CB 8A — RES 1, D {2}
def _CB_8A(c: *cpu.CPU) {
  *(c.D) = om.res8(c, *(c.D), 1);
}

// CB 8B — RES 1, E {2}
def _CB_8B(c: *cpu.CPU) {
  *(c.E) = om.res8(c, *(c.E), 1);
}

// CB 8C — RES 1, H {2}
def _CB_8C(c: *cpu.CPU) {
  *(c.H) = om.res8(c, *(c.H), 1);
}

// CB 8D — RES 1, L {2}
def _CB_8D(c: *cpu.CPU) {
  *(c.L) = om.res8(c, *(c.L), 1);
}

// CB 8E — RES 1, (HL) {3}
def _CB_8E(c: *cpu.CPU) {
  om.write8(c, c.HL, om.res8(c, om.read8(c, c.HL), 1));
}

// CB 8F — RES 1, A {2}
def _CB_8F(c: *cpu.CPU) {
  *(c.A) = om.res8(c, *(c.A), 1);
}

// CB 90 — RES 2, B {2}
def _CB_90(c: *cpu.CPU) {
  *(c.B) = om.res8(c, *(c.B), 2);
}

// CB 91 — RES 2, C {2}
def _CB_91(c: *cpu.CPU) {
  *(c.C) = om.res8(c, *(c.C), 2);
}

// CB 92 — RES 2, D {2}
def _CB_92(c: *cpu.CPU) {
  *(c.D) = om.res8(c, *(c.D), 2);
}

// CB 93 — RES 2, E {2}
def _CB_93(c: *cpu.CPU) {
  *(c.E) = om.res8(c, *(c.E), 2);
}

// CB 94 — RES 2, H {2}
def _CB_94(c: *cpu.CPU) {
  *(c.H) = om.res8(c, *(c.H), 2);
}

// CB 95 — RES 2, L {2}
def _CB_95(c: *cpu.CPU) {
  *(c.L) = om.res8(c, *(c.L), 2);
}

// CB 96 — RES 2, (HL) {3}
def _CB_96(c: *cpu.CPU) {
  om.write8(c, c.HL, om.res8(c, om.read8(c, c.HL), 2));
}

// CB 97 — RES 2, A {2}
def _CB_97(c: *cpu.CPU) {
  *(c.A) = om.res8(c, *(c.A), 2);
}

// CB 98 — RES 3, B {2}
def _CB_98(c: *cpu.CPU) {
  *(c.B) = om.res8(c, *(c.B), 3);
}

// CB 99 — RES 3, C {2}
def _CB_99(c: *cpu.CPU) {
  *(c.C) = om.res8(c, *(c.C), 3);
}

// CB 9A — RES 3, D {2}
def _CB_9A(c: *cpu.CPU) {
  *(c.D) = om.res8(c, *(c.D), 3);
}

// CB 9B — RES 3, E {2}
def _CB_9B(c: *cpu.CPU) {
  *(c.E) = om.res8(c, *(c.E), 3);
}

// CB 9C — RES 3, H {2}
def _CB_9C(c: *cpu.CPU) {
  *(c.H) = om.res8(c, *(c.H), 3);
}

// CB 9D — RES 3, L {2}
def _CB_9D(c: *cpu.CPU) {
  *(c.L) = om.res8(c, *(c.L), 3);
}

// CB 9E — RES 3, (HL) {3}
def _CB_9E(c: *cpu.CPU) {
  om.write8(c, c.HL, om.res8(c, om.read8(c, c.HL), 3));
}

// CB 9F — RES 3, A {2}
def _CB_9F(c: *cpu.CPU) {
  *(c.A) = om.res8(c, *(c.A), 3);
}

// CB A0 — RES 4, B {2}
def _CB_A0(c: *cpu.CPU) {
  *(c.B) = om.res8(c, *(c.B), 4);
}

// CB A1 — RES 4, C {2}
def _CB_A1(c: *cpu.CPU) {
  *(c.C) = om.res8(c, *(c.C), 4);
}

// CB A2 — RES 4, D {2}
def _CB_A2(c: *cpu.CPU) {
  *(c.D) = om.res8(c, *(c.D), 4);
}

// CB A3 — RES 4, E {2}
def _CB_A3(c: *cpu.CPU) {
  *(c.E) = om.res8(c, *(c.E), 4);
}

// CB A4 — RES 4, H {2}
def _CB_A4(c: *cpu.CPU) {
  *(c.H) = om.res8(c, *(c.H), 4);
}

// CB A5 — RES 4, L {2}
def _CB_A5(c: *cpu.CPU) {
  *(c.L) = om.res8(c, *(c.L), 4);
}

// CB A6 — RES 4, (HL) {3}
def _CB_A6(c: *cpu.CPU) {
  om.write8(c, c.HL, om.res8(c, om.read8(c, c.HL), 4));
}

// CB A7 — RES 4, A {2}
def _CB_A7(c: *cpu.CPU) {
  *(c.A) = om.res8(c, *(c.A), 4);
}

// CB A8 — RES 5, B {2}
def _CB_A8(c: *cpu.CPU) {
  *(c.B) = om.res8(c, *(c.B), 5);
}

// CB A9 — RES 5, C {2}
def _CB_A9(c: *cpu.CPU) {
  *(c.C) = om.res8(c, *(c.C), 5);
}

// CB AA — RES 5, D {2}
def _CB_AA(c: *cpu.CPU) {
  *(c.D) = om.res8(c, *(c.D), 5);
}

// CB AB — RES 5, E {2}
def _CB_AB(c: *cpu.CPU) {
  *(c.E) = om.res8(c, *(c.E), 5);
}

// CB AC — RES 5, H {2}
def _CB_AC(c: *cpu.CPU) {
  *(c.H) = om.res8(c, *(c.H), 5);
}

// CB AD — RES 5, L {2}
def _CB_AD(c: *cpu.CPU) {
  *(c.L) = om.res8(c, *(c.L), 5);
}

// CB AE — RES 5, (HL) {3}
def _CB_AE(c: *cpu.CPU) {
  om.write8(c, c.HL, om.res8(c, om.read8(c, c.HL), 5));
}

// CB AF — RES 5, A {2}
def _CB_AF(c: *cpu.CPU) {
  *(c.A) = om.res8(c, *(c.A), 5);
}

// CB B0 — RES 6, B {2}
def _CB_B0(c: *cpu.CPU) {
  *(c.B) = om.res8(c, *(c.B), 6);
}

// CB B1 — RES 6, C {2}
def _CB_B1(c: *cpu.CPU) {
  *(c.C) = om.res8(c, *(c.C), 6);
}

// CB B2 — RES 6, D {2}
def _CB_B2(c: *cpu.CPU) {
  *(c.D) = om.res8(c, *(c.D), 6);
}

// CB B3 — RES 6, E {2}
def _CB_B3(c: *cpu.CPU) {
  *(c.E) = om.res8(c, *(c.E), 6);
}

// CB B4 — RES 6, H {2}
def _CB_B4(c: *cpu.CPU) {
  *(c.H) = om.res8(c, *(c.H), 6);
}

// CB B5 — RES 6, L {2}
def _CB_B5(c: *cpu.CPU) {
  *(c.L) = om.res8(c, *(c.L), 6);
}

// CB B6 — RES 6, (HL) {3}
def _CB_B6(c: *cpu.CPU) {
  om.write8(c, c.HL, om.res8(c, om.read8(c, c.HL), 6));
}

// CB B7 — RES 6, A {2}
def _CB_B7(c: *cpu.CPU) {
  *(c.A) = om.res8(c, *(c.A), 6);
}

// CB B8 — RES 7, B {2}
def _CB_B8(c: *cpu.CPU) {
  *(c.B) = om.res8(c, *(c.B), 7);
}

// CB B9 — RES 7, C {2}
def _CB_B9(c: *cpu.CPU) {
  *(c.C) = om.res8(c, *(c.C), 7);
}

// CB BA — RES 7, D {2}
def _CB_BA(c: *cpu.CPU) {
  *(c.D) = om.res8(c, *(c.D), 7);
}

// CB BB — RES 7, E {2}
def _CB_BB(c: *cpu.CPU) {
  *(c.E) = om.res8(c, *(c.E), 7);
}

// CB BC — RES 7, H {2}
def _CB_BC(c: *cpu.CPU) {
  *(c.H) = om.res8(c, *(c.H), 7);
}

// CB BD — RES 7, L {2}
def _CB_BD(c: *cpu.CPU) {
  *(c.L) = om.res8(c, *(c.L), 7);
}

// CB BE — RES 7, (HL) {3}
def _CB_BE(c: *cpu.CPU) {
  om.write8(c, c.HL, om.res8(c, om.read8(c, c.HL), 7));
}

// CB BF — RES 7, A {2}
def _CB_BF(c: *cpu.CPU) {
  *(c.A) = om.res8(c, *(c.A), 7);
}

// CB C0 — SET 0, B {2}
def _CB_C0(c: *cpu.CPU) {
  *(c.B) = om.set8(c, *(c.B), 0);
}

// CB C1 — SET 0, C {2}
def _CB_C1(c: *cpu.CPU) {
  *(c.C) = om.set8(c, *(c.C), 0);
}

// CB C2 — SET 0, D {2}
def _CB_C2(c: *cpu.CPU) {
  *(c.D) = om.set8(c, *(c.D), 0);
}

// CB C3 — SET 0, E {2}
def _CB_C3(c: *cpu.CPU) {
  *(c.E) = om.set8(c, *(c.E), 0);
}

// CB C4 — SET 0, H {2}
def _CB_C4(c: *cpu.CPU) {
  *(c.H) = om.set8(c, *(c.H), 0);
}

// CB C5 — SET 0, L {2}
def _CB_C5(c: *cpu.CPU) {
  *(c.L) = om.set8(c, *(c.L), 0);
}

// CB C6 — SET 0, (HL) {3}
def _CB_C6(c: *cpu.CPU) {
  om.write8(c, c.HL, om.set8(c, om.read8(c, c.HL), 0));
}

// CB C7 — SET 0, A {2}
def _CB_C7(c: *cpu.CPU) {
  *(c.A) = om.set8(c, *(c.A), 0);
}

// CB C8 — SET 1, B {2}
def _CB_C8(c: *cpu.CPU) {
  *(c.B) = om.set8(c, *(c.B), 1);
}

// CB C9 — SET 1, C {2}
def _CB_C9(c: *cpu.CPU) {
  *(c.C) = om.set8(c, *(c.C), 1);
}

// CB CA — SET 1, D {2}
def _CB_CA(c: *cpu.CPU) {
  *(c.D) = om.set8(c, *(c.D), 1);
}

// CB CB — SET 1, E {2}
def _CB_CB(c: *cpu.CPU) {
  *(c.E) = om.set8(c, *(c.E), 1);
}

// CB CC — SET 1, H {2}
def _CB_CC(c: *cpu.CPU) {
  *(c.H) = om.set8(c, *(c.H), 1);
}

// CB CD — SET 1, L {2}
def _CB_CD(c: *cpu.CPU) {
  *(c.L) = om.set8(c, *(c.L), 1);
}

// CB CE — SET 1, (HL) {3}
def _CB_CE(c: *cpu.CPU) {
  om.write8(c, c.HL, om.set8(c, om.read8(c, c.HL), 1));
}

// CB CF — SET 1, A {2}
def _CB_CF(c: *cpu.CPU) {
  *(c.A) = om.set8(c, *(c.A), 1);
}

// CB D0 — SET 2, B {2}
def _CB_D0(c: *cpu.CPU) {
  *(c.B) = om.set8(c, *(c.B), 2);
}

// CB D1 — SET 2, C {2}
def _CB_D1(c: *cpu.CPU) {
  *(c.C) = om.set8(c, *(c.C), 2);
}

// CB D2 — SET 2, D {2}
def _CB_D2(c: *cpu.CPU) {
  *(c.D) = om.set8(c, *(c.D), 2);
}

// CB D3 — SET 2, E {2}
def _CB_D3(c: *cpu.CPU) {
  *(c.E) = om.set8(c, *(c.E), 2);
}

// CB D4 — SET 2, H {2}
def _CB_D4(c: *cpu.CPU) {
  *(c.H) = om.set8(c, *(c.H), 2);
}

// CB D5 — SET 2, L {2}
def _CB_D5(c: *cpu.CPU) {
  *(c.L) = om.set8(c, *(c.L), 2);
}

// CB D6 — SET 2, (HL) {3}
def _CB_D6(c: *cpu.CPU) {
  om.write8(c, c.HL, om.set8(c, om.read8(c, c.HL), 2));
}

// CB D7 — SET 2, A {2}
def _CB_D7(c: *cpu.CPU) {
  *(c.A) = om.set8(c, *(c.A), 2);
}

// CB D8 — SET 3, B {2}
def _CB_D8(c: *cpu.CPU) {
  *(c.B) = om.set8(c, *(c.B), 3);
}

// CB D9 — SET 3, C {2}
def _CB_D9(c: *cpu.CPU) {
  *(c.C) = om.set8(c, *(c.C), 3);
}

// CB DA — SET 3, D {2}
def _CB_DA(c: *cpu.CPU) {
  *(c.D) = om.set8(c, *(c.D), 3);
}

// CB DB — SET 3, E {2}
def _CB_DB(c: *cpu.CPU) {
  *(c.E) = om.set8(c, *(c.E), 3);
}

// CB DC — SET 3, H {2}
def _CB_DC(c: *cpu.CPU) {
  *(c.H) = om.set8(c, *(c.H), 3);
}

// CB DD — SET 3, L {2}
def _CB_DD(c: *cpu.CPU) {
  *(c.L) = om.set8(c, *(c.L), 3);
}

// CB DE — SET 3, (HL) {3}
def _CB_DE(c: *cpu.CPU) {
  om.write8(c, c.HL, om.set8(c, om.read8(c, c.HL), 3));
}

// CB DF — SET 3, A {2}
def _CB_DF(c: *cpu.CPU) {
  *(c.A) = om.set8(c, *(c.A), 3);
}

// CB E0 — SET 4, B {2}
def _CB_E0(c: *cpu.CPU) {
  *(c.B) = om.set8(c, *(c.B), 4);
}

// CB E1 — SET 4, C {2}
def _CB_E1(c: *cpu.CPU) {
  *(c.C) = om.set8(c, *(c.C), 4);
}

// CB E2 — SET 4, D {2}
def _CB_E2(c: *cpu.CPU) {
  *(c.D) = om.set8(c, *(c.D), 4);
}

// CB E3 — SET 4, E {2}
def _CB_E3(c: *cpu.CPU) {
  *(c.E) = om.set8(c, *(c.E), 4);
}

// CB E4 — SET 4, H {2}
def _CB_E4(c: *cpu.CPU) {
  *(c.H) = om.set8(c, *(c.H), 4);
}

// CB E5 — SET 4, L {2}
def _CB_E5(c: *cpu.CPU) {
  *(c.L) = om.set8(c, *(c.L), 4);
}

// CB E6 — SET 4, (HL) {3}
def _CB_E6(c: *cpu.CPU) {
  om.write8(c, c.HL, om.set8(c, om.read8(c, c.HL), 4));
}

// CB E7 — SET 4, A {2}
def _CB_E7(c: *cpu.CPU) {
  *(c.A) = om.set8(c, *(c.A), 4);
}

// CB E8 — SET 5, B {2}
def _CB_E8(c: *cpu.CPU) {
  *(c.B) = om.set8(c, *(c.B), 5);
}

// CB E9 — SET 5, C {2}
def _CB_E9(c: *cpu.CPU) {
  *(c.C) = om.set8(c, *(c.C), 5);
}

// CB EA — SET 5, D {2}
def _CB_EA(c: *cpu.CPU) {
  *(c.D) = om.set8(c, *(c.D), 5);
}

// CB EB — SET 5, E {2}
def _CB_EB(c: *cpu.CPU) {
  *(c.E) = om.set8(c, *(c.E), 5);
}

// CB EC — SET 5, H {2}
def _CB_EC(c: *cpu.CPU) {
  *(c.H) = om.set8(c, *(c.H), 5);
}

// CB ED — SET 5, L {2}
def _CB_ED(c: *cpu.CPU) {
  *(c.L) = om.set8(c, *(c.L), 5);
}

// CB EE — SET 5, (HL) {3}
def _CB_EE(c: *cpu.CPU) {
  om.write8(c, c.HL, om.set8(c, om.read8(c, c.HL), 5));
}

// CB EF — SET 5, A {2}
def _CB_EF(c: *cpu.CPU) {
  *(c.A) = om.set8(c, *(c.A), 5);
}

// CB F0 — SET 6, B {2}
def _CB_F0(c: *cpu.CPU) {
  *(c.B) = om.set8(c, *(c.B), 6);
}

// CB F1 — SET 6, C {2}
def _CB_F1(c: *cpu.CPU) {
  *(c.C) = om.set8(c, *(c.C), 6);
}

// CB F2 — SET 6, D {2}
def _CB_F2(c: *cpu.CPU) {
  *(c.D) = om.set8(c, *(c.D), 6);
}

// CB F3 — SET 6, E {2}
def _CB_F3(c: *cpu.CPU) {
  *(c.E) = om.set8(c, *(c.E), 6);
}

// CB F4 — SET 6, H {2}
def _CB_F4(c: *cpu.CPU) {
  *(c.H) = om.set8(c, *(c.H), 6);
}

// CB F5 — SET 6, L {2}
def _CB_F5(c: *cpu.CPU) {
  *(c.L) = om.set8(c, *(c.L), 6);
}

// CB F6 — SET 6, (HL) {3}
def _CB_F6(c: *cpu.CPU) {
  om.write8(c, c.HL, om.set8(c, om.read8(c, c.HL), 6));
}

// CB F7 — SET 6, A {2}
def _CB_F7(c: *cpu.CPU) {
  *(c.A) = om.set8(c, *(c.A), 6);
}

// CB F8 — SET 7, B {2}
def _CB_F8(c: *cpu.CPU) {
  *(c.B) = om.set8(c, *(c.B), 7);
}

// CB F9 — SET 7, C {2}
def _CB_F9(c: *cpu.CPU) {
  *(c.C) = om.set8(c, *(c.C), 7);
}

// CB FA — SET 7, D {2}
def _CB_FA(c: *cpu.CPU) {
  *(c.D) = om.set8(c, *(c.D), 7);
}

// CB FB — SET 7, E {2}
def _CB_FB(c: *cpu.CPU) {
  *(c.E) = om.set8(c, *(c.E), 7);
}

// CB FC — SET 7, H {2}
def _CB_FC(c: *cpu.CPU) {
  *(c.H) = om.set8(c, *(c.H), 7);
}

// CB FD — SET 7, L {2}
def _CB_FD(c: *cpu.CPU) {
  *(c.L) = om.set8(c, *(c.L), 7);
}

// CB FE — SET 7, (HL) {3}
def _CB_FE(c: *cpu.CPU) {
  om.write8(c, c.HL, om.set8(c, om.read8(c, c.HL), 7));
}

// CB FF — SET 7, A {2}
def _CB_FF(c: *cpu.CPU) {
  *(c.A) = om.set8(c, *(c.A), 7);
}
