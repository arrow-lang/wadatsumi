
// TODO: Determine if AF is stored as AF or FA in memory
// TODO: Finish opcodes
// TODO: Timing
// TODO: Tileset rendering

// libc
type size_t = int64;
type FILE = int64;
type c_long = int64;
type c_int = int32;

extern def exit(status: c_int);
extern def printf(format: str, ...);
extern def malloc(s: size_t): *uint8;
extern def memset(dst: *uint8, ch: c_int, count: size_t): *uint8;
extern def free(ptr: *uint8);
extern def fopen(filename: str, mode: str): *FILE;
extern def fclose(stream: *FILE);
extern def fread(buffer: *uint8, size: size_t, count: size_t, stream: *FILE): size_t;
extern def fseek(stream: *FILE, offset: c_long, origin: c_int): c_int;
extern def ftell(stream: *FILE): c_int;
extern def strncpy(dst: str, src: str, count: size_t): str;

// CPU
let ram: *uint8;
let cycles: float64;
let IME = false;
let PC: uint16 = 0;
let AF: uint16 = 0;
let A: *uint8 = (&AF as *uint8);
let F: *uint8 = (&AF as *uint8) + 1;
let BC: uint16 = 0;
let B: *uint8 = (&BC as *uint8);
let C: *uint8 = (&BC as *uint8) + 1;
let DE: uint16 = 0;
let D: *uint8 = (&DE as *uint8);
let E: *uint8 = (&DE as *uint8) + 1;
let HL: uint16 = 0;
let H: *uint8 = (&HL as *uint8);
let L: *uint8 = (&HL as *uint8) + 1;
let SP: uint16 = 0;

def main() {
  init();
  init_optable();
  init_cycletable();

  // open_rom("./missile-command.gb");
  // open_rom("./tetris.gb");
  // open_rom("./boxxle.gb");
  open_rom("./super-mario-land.gb");

  while true { execute(); }

  fini_optable();
  fini_cycletable();
  fini();
}

main();

def init() {
  ram = malloc(0x10000);
  reset();
}

def reset() {
  PC = 0x0100;
  SP = 0xFFFE;
  IME = true;

  AF = 0x01B0;
  BC = 0x0013;
  DE = 0x00D8;
  HL = 0x014D;

  *(ram + 0xFF05) = 0x00;
  *(ram + 0xFF06) = 0x00;
  *(ram + 0xFF07) = 0x00;
  *(ram + 0xFF10) = 0x80;
  *(ram + 0xFF11) = 0xBF;
  *(ram + 0xFF12) = 0xF3;
  *(ram + 0xFF14) = 0xBF;
  *(ram + 0xFF16) = 0x3F;
  *(ram + 0xFF17) = 0x00;
  *(ram + 0xFF19) = 0xBF;
  *(ram + 0xFF1A) = 0x7F;
  *(ram + 0xFF1B) = 0xFF;
  *(ram + 0xFF1C) = 0x9F;
  *(ram + 0xFF1E) = 0xBF;
  *(ram + 0xFF20) = 0xFF;
  *(ram + 0xFF21) = 0x00;
  *(ram + 0xFF22) = 0x00;
  *(ram + 0xFF23) = 0xBF;
  *(ram + 0xFF24) = 0x77;
  *(ram + 0xFF25) = 0xF3;
  // NOTE: $FF26 should be F0 for SGB
  *(ram + 0xFF26) = 0xF1;
  *(ram + 0xFF40) = 0x91;
  *(ram + 0xFF42) = 0x00;
  *(ram + 0xFF43) = 0x00;
  *(ram + 0xFF45) = 0x00;
  *(ram + 0xFF47) = 0xFC;
  *(ram + 0xFF48) = 0xFF;
  *(ram + 0xFF49) = 0xFF;
  *(ram + 0xFF4A) = 0x00;
  *(ram + 0xFF4B) = 0x00;
  *(ram + 0xFFFF) = 0x00;
}

def fini() {
  free(ram);
}

def open_rom(filename: str) {
  // Open a file handle to the ROM
  let stream = fopen(filename, "rb");
  if stream == 0 as *FILE {
    printf("error: couldn't read \"%s\"; couldn't open path as file\n",
      filename);

    exit(1);
  }

  // Get size of file stream
  fseek(stream, 0, 2);
  let length = ftell(stream);
  fseek(stream, 0, 0);

  // NOTE: Pretend the ROM can't possibly be bigger than 32KiB
  fread(ram, 1, length, stream);

  // Print out the ROM name
  let title = malloc(0x10) as str;
  strncpy(title, (ram + 0x134) as str, 0x10);
  printf("open: %s\n", title);
  free(title as *uint8);
}

// =============================================================================
// [MMU] Memory Management Unit
// =============================================================================

// Read 8-bits
def mmu_read8(address: uint16): uint8 {
  return *(ram + address);
}

// Read 16-bits
def mmu_read16(address: uint16): uint16 {
  let l = mmu_read8(address + 0);
  let h = mmu_read8(address + 1);

  return uint16(l) | (uint16(h) << 8);
}

// Read IMMEDIATE 8-bits
def mmu_next8(): uint8 {
  let value = mmu_read8(PC);
  PC += 1;

  return value;
}

// Read IMMEDIATE 16-bits
def mmu_next16(): uint16 {
  let value = mmu_read16(PC);
  PC += 1;

  return value;
}

// Write 8-bits
def mmu_write8(address: uint16, value: uint8) {
  *(ram + address) = value;
}

// Write 16-bits
def mmu_write16(address: uint16, value: uint16) {
  *(ram + address) = uint8(value & 0xFF);
  *(ram + address + 1) = uint8(value >> 8);
}

// =============================================================================
// [OT] Operation Table
// =============================================================================
let optable: *(() -> ());

def init_optable() {
  optable = malloc(0x1_00 * 8) as *(() -> ());
  memset(optable as *uint8, 0, 0x1_00 * 8);

  *(optable + 0x00) = op_00;
  *(optable + 0x01) = op_01;
  *(optable + 0x02) = op_02;
  *(optable + 0x03) = op_03;
  *(optable + 0x04) = op_04;
  *(optable + 0x05) = op_05;
  *(optable + 0x06) = op_06;
  // TODO: *(optable + 0x07) = op_07;
  *(optable + 0x08) = op_08;
  *(optable + 0x09) = op_09;
  *(optable + 0x0A) = op_0A;
  *(optable + 0x0B) = op_0B;
  *(optable + 0x0C) = op_0C;
  *(optable + 0x0D) = op_0D;
  *(optable + 0x0E) = op_0E;
  // TODO: *(optable + 0x0F) = op_0F;

  // TODO: *(optable + 0x10) = op_10;
  *(optable + 0x11) = op_11;
  *(optable + 0x12) = op_12;
  *(optable + 0x13) = op_13;
  *(optable + 0x14) = op_14;
  *(optable + 0x15) = op_15;
  *(optable + 0x16) = op_16;
  // TODO: *(optable + 0x17) = op_17;
  *(optable + 0x18) = op_18;
  *(optable + 0x19) = op_19;
  *(optable + 0x1A) = op_1A;
  *(optable + 0x1B) = op_1B;
  *(optable + 0x1C) = op_1C;
  *(optable + 0x1D) = op_1D;
  *(optable + 0x1E) = op_1E;
  // TODO: *(optable + 0x1F) = op_1F;

  *(optable + 0x20) = op_20;
  *(optable + 0x21) = op_21;
  *(optable + 0x22) = op_22;
  *(optable + 0x23) = op_23;
  *(optable + 0x24) = op_24;
  *(optable + 0x25) = op_25;
  *(optable + 0x26) = op_26;
  *(optable + 0x27) = op_27;
  *(optable + 0x28) = op_28;
  *(optable + 0x29) = op_29;
  *(optable + 0x2A) = op_2A;
  *(optable + 0x2B) = op_2B;
  *(optable + 0x2C) = op_2C;
  *(optable + 0x2D) = op_2D;
  *(optable + 0x2E) = op_2E;
  *(optable + 0x2F) = op_2F;

  *(optable + 0x30) = op_30;
  *(optable + 0x31) = op_31;
  *(optable + 0x32) = op_32;
  *(optable + 0x33) = op_33;
  *(optable + 0x34) = op_34;
  *(optable + 0x35) = op_35;
  *(optable + 0x36) = op_36;
  *(optable + 0x37) = op_37;
  *(optable + 0x38) = op_38;
  *(optable + 0x39) = op_39;
  *(optable + 0x3A) = op_3A;
  *(optable + 0x3B) = op_3B;
  *(optable + 0x3C) = op_3C;
  *(optable + 0x3D) = op_3D;
  *(optable + 0x3E) = op_3E;
  *(optable + 0x3F) = op_3F;

  *(optable + 0x40) = op_40;
  *(optable + 0x41) = op_41;
  *(optable + 0x42) = op_42;
  *(optable + 0x43) = op_43;
  *(optable + 0x44) = op_44;
  *(optable + 0x45) = op_45;
  *(optable + 0x46) = op_46;
  *(optable + 0x47) = op_47;
  *(optable + 0x48) = op_48;
  *(optable + 0x49) = op_49;
  *(optable + 0x4A) = op_4A;
  *(optable + 0x4B) = op_4B;
  *(optable + 0x4C) = op_4C;
  *(optable + 0x4D) = op_4D;
  *(optable + 0x4E) = op_4E;
  *(optable + 0x4F) = op_4F;

  *(optable + 0x50) = op_50;
  *(optable + 0x51) = op_51;
  *(optable + 0x52) = op_52;
  *(optable + 0x53) = op_53;
  *(optable + 0x54) = op_54;
  *(optable + 0x55) = op_55;
  *(optable + 0x56) = op_56;
  *(optable + 0x57) = op_57;
  *(optable + 0x58) = op_58;
  *(optable + 0x59) = op_59;
  *(optable + 0x5A) = op_5A;
  *(optable + 0x5B) = op_5B;
  *(optable + 0x5C) = op_5C;
  *(optable + 0x5D) = op_5D;
  *(optable + 0x5E) = op_5E;
  *(optable + 0x5F) = op_5F;

  *(optable + 0x60) = op_60;
  *(optable + 0x61) = op_61;
  *(optable + 0x62) = op_62;
  *(optable + 0x63) = op_63;
  *(optable + 0x64) = op_64;
  *(optable + 0x65) = op_65;
  *(optable + 0x66) = op_66;
  *(optable + 0x67) = op_67;
  *(optable + 0x68) = op_68;
  *(optable + 0x69) = op_69;
  *(optable + 0x6A) = op_6A;
  *(optable + 0x6B) = op_6B;
  *(optable + 0x6C) = op_6C;
  *(optable + 0x6D) = op_6D;
  *(optable + 0x6E) = op_6E;
  *(optable + 0x6F) = op_6F;

  *(optable + 0x80) = op_80;
  *(optable + 0x81) = op_81;
  *(optable + 0x82) = op_82;
  *(optable + 0x83) = op_83;
  *(optable + 0x84) = op_84;
  *(optable + 0x85) = op_85;
  *(optable + 0x86) = op_86;
  *(optable + 0x87) = op_87;
  *(optable + 0x88) = op_88;
  *(optable + 0x89) = op_89;
  *(optable + 0x8A) = op_8A;
  *(optable + 0x8B) = op_8B;
  *(optable + 0x8C) = op_8C;
  *(optable + 0x8D) = op_8D;
  *(optable + 0x8E) = op_8E;
  *(optable + 0x8F) = op_8F;

  *(optable + 0x90) = op_90;
  *(optable + 0x91) = op_91;
  *(optable + 0x92) = op_92;
  *(optable + 0x93) = op_93;
  *(optable + 0x94) = op_94;
  *(optable + 0x95) = op_95;
  *(optable + 0x96) = op_96;
  *(optable + 0x97) = op_97;
  *(optable + 0x98) = op_98;
  *(optable + 0x99) = op_99;
  *(optable + 0x9A) = op_9A;
  *(optable + 0x9B) = op_9B;
  *(optable + 0x9C) = op_9C;
  *(optable + 0x9D) = op_9D;
  *(optable + 0x9E) = op_9E;
  *(optable + 0x9F) = op_9F;

  *(optable + 0xA0) = op_A0;
  *(optable + 0xA1) = op_A1;
  *(optable + 0xA2) = op_A2;
  *(optable + 0xA3) = op_A3;
  *(optable + 0xA4) = op_A4;
  *(optable + 0xA5) = op_A5;
  *(optable + 0xA6) = op_A6;
  *(optable + 0xA7) = op_A7;
  *(optable + 0xA8) = op_A8;
  *(optable + 0xA9) = op_A9;
  *(optable + 0xAA) = op_AA;
  *(optable + 0xAB) = op_AB;
  *(optable + 0xAC) = op_AC;
  *(optable + 0xAD) = op_AD;
  *(optable + 0xAE) = op_AE;
  *(optable + 0xAF) = op_AF;

  *(optable + 0xB0) = op_B0;
  *(optable + 0xB1) = op_B1;
  *(optable + 0xB2) = op_B2;
  *(optable + 0xB3) = op_B3;
  *(optable + 0xB4) = op_B4;
  *(optable + 0xB5) = op_B5;
  *(optable + 0xB6) = op_B6;
  *(optable + 0xB7) = op_B7;
  *(optable + 0xB8) = op_B8;
  *(optable + 0xB9) = op_B9;
  *(optable + 0xBA) = op_BA;
  *(optable + 0xBB) = op_BB;
  *(optable + 0xBC) = op_BC;
  *(optable + 0xBD) = op_BD;
  *(optable + 0xBE) = op_BE;
  *(optable + 0xBF) = op_BF;

  *(optable + 0xC0) = op_C0;
  *(optable + 0xC1) = op_C1;
  *(optable + 0xC2) = op_C2;
  *(optable + 0xC3) = op_C3;
  *(optable + 0xC4) = op_C4;
  *(optable + 0xC5) = op_C5;
  *(optable + 0xC6) = op_C6;
  *(optable + 0xC7) = op_C7;
  *(optable + 0xC8) = op_C8;
  *(optable + 0xC9) = op_C9;
  *(optable + 0xCA) = op_CA;
  *(optable + 0xCB) = op_CB;
  *(optable + 0xCC) = op_CC;
  *(optable + 0xCD) = op_CD;
  *(optable + 0xCE) = op_CE;
  *(optable + 0xCF) = op_CF;

  // TODO: *(optable + 0xD0) = op_D0;
  // TODO: *(optable + 0xD1) = op_D1;
  // TODO: *(optable + 0xD2) = op_D2;
  // *(optable + 0xD3) = _
  // TODO: *(optable + 0xD4) = op_D4;
  *(optable + 0xD5) = op_D5;
  // TODO: *(optable + 0xD6) = op_D6;
  // TODO: *(optable + 0xD7) = op_D7;
  // TODO: *(optable + 0xD8) = op_D8;
  // TODO: *(optable + 0xD9) = op_D9;
  // TODO: *(optable + 0xDA) = op_DA;
  // *(optable + 0xDB) = _
  // TODO: *(optable + 0xDC) = op_DC;
  // *(optable + 0xDD) = _
  // TODO: *(optable + 0xDE) = op_DE;
  *(optable + 0xDF) = op_DF;

  *(optable + 0xE0) = op_E0;
  *(optable + 0xE1) = op_E1;
  *(optable + 0xE2) = op_E2;
  // *(optable + 0xE3) = _
  // *(optable + 0xE4) = _
  *(optable + 0xE5) = op_E5;
  *(optable + 0xE6) = op_E6;
  *(optable + 0xE7) = op_E7;
  *(optable + 0xE8) = op_E8;
  *(optable + 0xE9) = op_E9;
  *(optable + 0xEA) = op_EA;
  // *(optable + 0xEB) = _
  // *(optable + 0xEC) = _
  // *(optable + 0xED) = _
  *(optable + 0xEE) = op_EE;
  *(optable + 0xEF) = op_EF;

  *(optable + 0xF0) = op_F0;
  *(optable + 0xF1) = op_F1;
  *(optable + 0xF2) = op_F2;
  *(optable + 0xF3) = op_F3;
  // *(optable + 0xF4) = _
  *(optable + 0xF5) = op_F5;
  *(optable + 0xF6) = op_F6;
  *(optable + 0xF7) = op_F7;
  *(optable + 0xF8) = op_F8;
  // TODO: *(optable + 0xF9) = op_F9;
  *(optable + 0xFA) = op_FA;
  *(optable + 0xFB) = op_FB;
  // *(optable + 0xFC) = _
  // *(optable + 0xFD) = _
  *(optable + 0xFE) = op_FE;
  *(optable + 0xFF) = op_FF;
}

def fini_optable() {
  free(optable as *uint8);
}

// =============================================================================
// [CT] Cycle Table
// =============================================================================
let cycletable: *uint8;

def init_cycletable() {
  cycletable = malloc(0x1_00) as *uint8;
  memset(cycletable as *uint8, 0, 0x1_00);

  *(cycletable + 0x00) = 4;
  *(cycletable + 0x01) = 12;
  *(cycletable + 0x02) = 8;
  *(cycletable + 0x03) = 8;
  *(cycletable + 0x04) = 4;
  *(cycletable + 0x05) = 4;
  *(cycletable + 0x06) = 8;
  *(cycletable + 0x07) = 4;
  *(cycletable + 0x08) = 20;
  *(cycletable + 0x09) = 8;
  *(cycletable + 0x0A) = 8;
  *(cycletable + 0x0B) = 8;
  *(cycletable + 0x0C) = 4;
  *(cycletable + 0x0D) = 4;
  *(cycletable + 0x0E) = 8;
  *(cycletable + 0x0F) = 4;

  *(cycletable + 0x10) = 4;
  *(cycletable + 0x11) = 12;
  *(cycletable + 0x12) = 8;
  *(cycletable + 0x13) = 8;
  *(cycletable + 0x14) = 4;
  *(cycletable + 0x15) = 4;
  *(cycletable + 0x16) = 8;
  *(cycletable + 0x17) = 4;
  *(cycletable + 0x18) = 12;
  *(cycletable + 0x19) = 8;
  *(cycletable + 0x1A) = 8;
  *(cycletable + 0x1B) = 8;
  *(cycletable + 0x1C) = 4;
  *(cycletable + 0x1D) = 4;
  *(cycletable + 0x1E) = 8;
  *(cycletable + 0x1F) = 4;

  *(cycletable + 0x20) = 8;  //  +4 IFF
  *(cycletable + 0x21) = 12;
  *(cycletable + 0x22) = 8;
  *(cycletable + 0x23) = 8;
  *(cycletable + 0x24) = 4;
  *(cycletable + 0x25) = 4;
  *(cycletable + 0x26) = 8;
  *(cycletable + 0x27) = 4;
  *(cycletable + 0x28) = 8;  //  +4 IFF
  *(cycletable + 0x29) = 8;
  *(cycletable + 0x2A) = 8;
  *(cycletable + 0x2B) = 8;
  *(cycletable + 0x2C) = 4;
  *(cycletable + 0x2D) = 4;
  *(cycletable + 0x2E) = 8;
  *(cycletable + 0x2F) = 4;

  *(cycletable + 0x30) = 8;  //  +4 IFF
  *(cycletable + 0x31) = 12;
  *(cycletable + 0x32) = 8;
  *(cycletable + 0x33) = 8;
  *(cycletable + 0x34) = 12;
  *(cycletable + 0x35) = 12;
  *(cycletable + 0x36) = 12;
  *(cycletable + 0x37) = 4;
  *(cycletable + 0x38) = 8;  //  +4 IFF
  *(cycletable + 0x39) = 8;
  *(cycletable + 0x3A) = 8;
  *(cycletable + 0x3B) = 8;
  *(cycletable + 0x3C) = 4;
  *(cycletable + 0x3D) = 4;
  *(cycletable + 0x3E) = 8;
  *(cycletable + 0x3F) = 4;

  *(cycletable + 0x40) = 4;
  *(cycletable + 0x41) = 4;
  *(cycletable + 0x42) = 4;
  *(cycletable + 0x43) = 4;
  *(cycletable + 0x44) = 4;
  *(cycletable + 0x45) = 4;
  *(cycletable + 0x46) = 8;
  *(cycletable + 0x47) = 4;
  *(cycletable + 0x48) = 4;
  *(cycletable + 0x49) = 4;
  *(cycletable + 0x4A) = 4;
  *(cycletable + 0x4B) = 4;
  *(cycletable + 0x4C) = 4;
  *(cycletable + 0x4D) = 4;
  *(cycletable + 0x4E) = 8;
  *(cycletable + 0x4F) = 4;

  *(cycletable + 0x50) = 4;
  *(cycletable + 0x51) = 4;
  *(cycletable + 0x52) = 4;
  *(cycletable + 0x53) = 4;
  *(cycletable + 0x54) = 4;
  *(cycletable + 0x55) = 4;
  *(cycletable + 0x56) = 8;
  *(cycletable + 0x57) = 4;
  *(cycletable + 0x58) = 4;
  *(cycletable + 0x59) = 4;
  *(cycletable + 0x5A) = 4;
  *(cycletable + 0x5B) = 4;
  *(cycletable + 0x5C) = 4;
  *(cycletable + 0x5D) = 4;
  *(cycletable + 0x5E) = 8;
  *(cycletable + 0x5F) = 4;

  *(cycletable + 0x60) = 4;
  *(cycletable + 0x61) = 4;
  *(cycletable + 0x62) = 4;
  *(cycletable + 0x63) = 4;
  *(cycletable + 0x64) = 4;
  *(cycletable + 0x65) = 4;
  *(cycletable + 0x66) = 8;
  *(cycletable + 0x67) = 4;
  *(cycletable + 0x68) = 4;
  *(cycletable + 0x69) = 4;
  *(cycletable + 0x6A) = 4;
  *(cycletable + 0x6B) = 4;
  *(cycletable + 0x6C) = 4;
  *(cycletable + 0x6D) = 4;
  *(cycletable + 0x6E) = 8;
  *(cycletable + 0x6F) = 4;

  *(cycletable + 0x80) = 4;
  *(cycletable + 0x81) = 4;
  *(cycletable + 0x82) = 4;
  *(cycletable + 0x83) = 4;
  *(cycletable + 0x84) = 4;
  *(cycletable + 0x85) = 4;
  *(cycletable + 0x86) = 8;
  *(cycletable + 0x87) = 4;
  *(cycletable + 0x88) = 4;
  *(cycletable + 0x89) = 4;
  *(cycletable + 0x8A) = 4;
  *(cycletable + 0x8B) = 4;
  *(cycletable + 0x8C) = 4;
  *(cycletable + 0x8D) = 4;
  *(cycletable + 0x8E) = 8;
  *(cycletable + 0x8F) = 4;

  *(cycletable + 0x90) = 4;
  *(cycletable + 0x91) = 4;
  *(cycletable + 0x92) = 4;
  *(cycletable + 0x93) = 4;
  *(cycletable + 0x94) = 4;
  *(cycletable + 0x95) = 4;
  *(cycletable + 0x96) = 8;
  *(cycletable + 0x97) = 4;
  *(cycletable + 0x98) = 4;
  *(cycletable + 0x99) = 4;
  *(cycletable + 0x9A) = 4;
  *(cycletable + 0x9B) = 4;
  *(cycletable + 0x9C) = 4;
  *(cycletable + 0x9D) = 4;
  *(cycletable + 0x9E) = 8;
  *(cycletable + 0x9F) = 4;

  *(cycletable + 0xA0) = 4;
  *(cycletable + 0xA1) = 4;
  *(cycletable + 0xA2) = 4;
  *(cycletable + 0xA3) = 4;
  *(cycletable + 0xA4) = 4;
  *(cycletable + 0xA5) = 4;
  *(cycletable + 0xA6) = 8;
  *(cycletable + 0xA7) = 4;
  *(cycletable + 0xA8) = 4;
  *(cycletable + 0xA9) = 4;
  *(cycletable + 0xAA) = 4;
  *(cycletable + 0xAB) = 4;
  *(cycletable + 0xAC) = 4;
  *(cycletable + 0xAD) = 4;
  *(cycletable + 0xAE) = 8;
  *(cycletable + 0xAF) = 4;

  *(cycletable + 0xB0) = 4;
  *(cycletable + 0xB1) = 4;
  *(cycletable + 0xB2) = 4;
  *(cycletable + 0xB3) = 4;
  *(cycletable + 0xB4) = 4;
  *(cycletable + 0xB5) = 4;
  *(cycletable + 0xB6) = 8;
  *(cycletable + 0xB7) = 4;
  *(cycletable + 0xB8) = 4;
  *(cycletable + 0xB9) = 4;
  *(cycletable + 0xBA) = 4;
  *(cycletable + 0xBB) = 4;
  *(cycletable + 0xBC) = 4;
  *(cycletable + 0xBD) = 4;
  *(cycletable + 0xBE) = 8;
  *(cycletable + 0xBF) = 4;

  *(cycletable + 0xC0) = 8;   // +12 IFF
  *(cycletable + 0xC1) = 12;
  *(cycletable + 0xC2) = 12;  //  +4 IFF
  *(cycletable + 0xC3) = 16;
  *(cycletable + 0xC4) = 12;  // +12 IFF
  *(cycletable + 0xC5) = 16;
  *(cycletable + 0xC6) = 8;
  *(cycletable + 0xC7) = 16;
  *(cycletable + 0xC8) = 8;   // +12 IFF
  *(cycletable + 0xC9) = 16;
  *(cycletable + 0xCA) = 12;  //  +4 IFF
  *(cycletable + 0xCC) = 12;  // +12 IFF
  *(cycletable + 0xCD) = 24;
  *(cycletable + 0xCE) = 8;
  *(cycletable + 0xCF) = 16;

  *(cycletable + 0xD0) = 8;   // +12 IFF
  *(cycletable + 0xD1) = 12;
  *(cycletable + 0xD2) = 12;  //  +4 IFF
  // *(cycletable + 0xD3) = _
  *(cycletable + 0xD4) = 12;  // +12 IFF
  *(cycletable + 0xD5) = 16;
  *(cycletable + 0xD6) = 8;
  *(cycletable + 0xD7) = 16;
  *(cycletable + 0xD8) = 8;   // +12 IFF
  *(cycletable + 0xD9) = 16;
  *(cycletable + 0xDA) = 12;  //  +4 IFF
  // *(cycletable + 0xDB) = _
  *(cycletable + 0xDC) = 12;  // +12 IFF
  // *(cycletable + 0xDD) = _
  *(cycletable + 0xDE) = 8;
  *(cycletable + 0xDF) = 16;

  *(cycletable + 0xE0) = 12;
  *(cycletable + 0xE1) = 12;
  *(cycletable + 0xE2) = 8;
  // *(cycletable + 0xE3) = _
  // *(cycletable + 0xE4) = _
  *(cycletable + 0xE5) = 16;
  *(cycletable + 0xE6) = 8;
  *(cycletable + 0xE7) = 16;
  *(cycletable + 0xE8) = 16;
  *(cycletable + 0xE9) = 4;
  *(cycletable + 0xEA) = 16;
  // *(cycletable + 0xEB) = _
  // *(cycletable + 0xEC) = _
  // *(cycletable + 0xED) = _
  *(cycletable + 0xEE) = 8;
  *(cycletable + 0xEF) = 16;

  *(cycletable + 0xF0) = 12;
  *(cycletable + 0xF1) = 12;
  *(cycletable + 0xF2) = 8;
  *(cycletable + 0xF3) = 4;
  // *(cycletable + 0xF4) = _
  *(cycletable + 0xF5) = 16;
  *(cycletable + 0xF6) = 8;
  *(cycletable + 0xF7) = 16;
  *(cycletable + 0xF8) = 12;
  *(cycletable + 0xF9) = 8;
  *(cycletable + 0xFA) = 16;
  *(cycletable + 0xFB) = 4;
  // *(cycletable + 0xFC) = _
  // *(cycletable + 0xFD) = _
  *(cycletable + 0xFE) = 8;
  *(cycletable + 0xFF) = 16;
}

def fini_cycletable() {
  free(cycletable as *uint8);
}

// =============================================================================
// [FL] Flag
// =============================================================================
type Flag = uint8;

let FLAG_Z: Flag = 0b1000_0000;
let FLAG_N: Flag = 0b0100_0000;
let FLAG_H: Flag = 0b0010_0000;
let FLAG_C: Flag = 0b0001_0000;

def flag_set(flag: Flag, value: bool) {
  if value { *F |=  uint8(flag); }
  else     { *F &= ~uint8(flag); }
}

def flag_get(flag: Flag): bool {
  return *F & uint8(flag) != 0;
}

def flag_geti(flag: Flag): uint8 {
  return if flag_get(flag) { 1; } else { 0; };
}

// =============================================================================
// [OM] Operation Mnemonics
// =============================================================================

// Increment 8-bit Register
def om_inc8(r: *uint8) {
  flag_set(FLAG_H, (((*r & 0xF) + (1 & 0xF)) & 0x10) > 0);

  *r += 1;

  flag_set(FLAG_Z, *r == 0);
  flag_set(FLAG_N, false);
}

// Decrement 8-bit Register
def om_dec8(r: *uint8) {
  flag_set(FLAG_H, (((*r & 0xF) - (1 & 0xF)) & 0x10) < 0);

  *r -= 1;

  flag_set(FLAG_Z, *r == 0);
  flag_set(FLAG_N, true);
}

// Increment 16-bit Register
def om_inc16(r: *uint16) {
  *r += 1;
}

// Decrement 16-bit Register
def om_dec16(r: *uint16) {
  *r -= 1;
}

// And 8-bit value
def om_and8(a: uint8, b: uint8): uint8 {
  let r = a & b;

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, true);
  flag_set(FLAG_C, false);

  return r;
}

// Or 8-bit value
def om_or8(a: uint8, b: uint8): uint8 {
  let r = a & b;

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, false);
  flag_set(FLAG_C, false);

  return r;
}

// Xor 8-bit value
def om_xor8(a: uint8, b: uint8): uint8 {
  let r = a ^ b;

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, false);
  flag_set(FLAG_C, false);

  return r;
}

// Add 8-bit value
def om_add8(a: uint8, b: uint8): uint8 {
  flag_set(FLAG_H, (((a & 0xF) + (b & 0xF)) & 0x10) > 0);

  let r = uint16(a) + uint16(b);

  flag_set(FLAG_C, r > 0xFFFF);
  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);

  return uint8(r & 0xFF);
}

// Add 8-bit value w/carry
def om_adc8(a: uint8, b: uint8): uint8 {
  return om_add8(a, b + uint8(flag_geti(FLAG_C)));
}

// Subtract 8-bit value
def om_sub8(a: uint8, b: uint8): uint8 {
  let r = om_add8(a, ~b);

  flag_set(FLAG_N, true);

  return r;
}

// Subtract 8-bit value w/carry
def om_sbc8(a: uint8, b: uint8): uint8 {
  let r = om_adc8(a, ~b);

  flag_set(FLAG_N, true);

  return r;
}

// Add 16-bit value
def om_add16(a: uint16, b: uint16): uint16 {
  flag_set(FLAG_H, (((a & 0xFF) + (b & 0xFF)) & 0x100) > 0);

  let r = uint32(a) + uint32(b);

  flag_set(FLAG_C, r > 0xFFFF);
  flag_set(FLAG_N, false);

  return uint16(r & 0xFFFF);
}

// Add 16-bit value w/carry
def om_adc16(a: uint16, b: uint16): uint16 {
  return om_add16(a, b + uint16(flag_geti(FLAG_C)));
}

// Subtract 16-bit value
def om_sub16(a: uint16, b: uint16): uint16 {
  let r = om_add16(a, ~b);

  flag_set(FLAG_N, true);

  return r;
}

// Subtract 16-bit value w/carry
def om_sbc16(a: uint16, b: uint16): uint16 {
  let r = om_adc16(a, ~b);

  flag_set(FLAG_N, true);

  return r;
}

// Push 16-bit value
def om_push16(r: *uint16) {
  SP -= 2;
  mmu_write16(SP, *r);
}

// Pop 16-bit value
def om_pop16(r: *uint16) {
  *r = mmu_read16(SP);
  SP += 2;
}

// Jump
def om_jp(address: uint16) {
  PC = address;
}

// Call
def om_call(address: uint16) {
  om_push16(&PC);
  om_jp(address);
}

// Return
def om_ret() {
  om_pop16(&PC);
}

// Return (and enable interrupts)
def om_reti() {
  IME = true;
  om_ret();
}

// =============================================================================
// [OP] Operations
// =============================================================================

// [00] NOP
def op_00() {
  // Do nothing
}

// [01] LD BC, nn
def op_01() {
  BC = mmu_next16();
}

// [02] LD (BC), A
def op_02() {
  mmu_write8(BC, *A);
}

// [03] INC BC
def op_03() {
  om_inc16(&BC);
}

// [04] INC B
def op_04() {
  om_inc8(B);
}

// [05] DEC B
def op_05() {
  om_dec8(B);
}

// [06] LD B, n
def op_06() {
  *B = mmu_next8();
}

// TODO: [07] RLCA

// [08] LD (nn), SP
def op_08() {
  mmu_write16(mmu_next16(), SP);
}

// [09] ADD HL, BC
def op_09() {
  HL = om_add16(HL, BC);
}

// [0A] LD A, (BC)
def op_0A() {
  *A = mmu_read8(BC);
}

// [0B] DEC BC
def op_0B() {
  om_dec16(&BC);
}

// [0C] INC C
def op_0C() {
  om_inc8(C);
}

// [0D] DEC C
def op_0D() {
  om_dec8(C);
}

// [0E] LD C, n
def op_0E() {
  *C = mmu_next8();
}

// TODO: [0F] RRCA

// TODO: [10] STOP

// [11] LD DE, nn
def op_11() {
  DE = mmu_next16();
}

// [12] LD (DE), A
def op_12() {
  mmu_write8(DE, *A);
}

// [13] INC DE
def op_13() {
  om_inc16(&DE);
}

// [14] INC D
def op_14() {
  om_inc8(D);
}

// [15] DEC D
def op_15() {
  om_dec8(D);
}

// [16] LD D, n
def op_16() {
  *D = mmu_next8();
}

// TODO: [17] RLA

// [18] JR n
def op_18() {
  let n = mmu_next8();
  om_jp(PC + uint16(n));
}

// [19] ADD HL, DE
def op_19() {
  HL = om_add16(HL, DE);
}

// [1A] LD A, (DE)
def op_1A() {
  *A = mmu_read8(DE);
}

// [1B] DEC DE
def op_1B() {
  om_dec16(&DE);
}

// [1C] INC E
def op_1C() {
  om_inc8(E);
}

// [1D] DEC E
def op_1D() {
  om_dec8(E);
}

// [1E] LD E, n
def op_1E() {
  *E = mmu_next8();
}

// TODO: [1F] RRA

// [20] JR NZ, n
def op_20() {
  let n = mmu_next8();
  if not flag_get(FLAG_Z) {
    om_jp(PC + uint16(n));
    cycles += 4;
  }
}

// [21] LD HL, nn
def op_21() {
  HL = mmu_next16();
}

// [22] LDI (HL), A
def op_22() {
  mmu_write8(HL, *A);
  HL += 1;
}

// [23] INC HL
def op_23() {
  om_inc16(&HL);
}

// [24] INC H
def op_24() {
  om_inc8(H);
}

// [25] DEC H
def op_25() {
  om_dec8(H);
}

// [26] LD H, n
def op_26() {
  *H = mmu_next8();
}

// [27] DAA
def op_27() {
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

  let r = uint16(*A);

  if (r & 0xF) > 9 or flag_get(FLAG_H) {
    if flag_get(FLAG_N) {
      r -= 0x06;
    } else {
      r += 0x06;
    }
  }

  // If the upper 4 bits form a number greater than 9 or C is set,
  // add $60 to the accumulator
  if ((r >> 4) & 0xF) > 9 or flag_get(FLAG_H) {
    if flag_get(FLAG_N) {
      r -= 0x60;
    } else {
      r += 0x60;
    }
  }

  flag_set(FLAG_C, r & 0x100 != 0);
  flag_set(FLAG_H, false);

  *A = uint8(r);

  flag_set(FLAG_Z, *A == 0);
}

// [28] JR Z, n
def op_28() {
  let n = mmu_next8();
  if flag_get(FLAG_Z) {
    om_jp(PC + uint16(n));
    cycles += 4;
  }
}

// [29] ADD HL, HL
def op_29() {
  HL = om_add16(HL, HL);
}

// [2A] LDI A, (HL)
def op_2A() {
  *A = mmu_read8(HL);
  HL += 1;
}

// [2B] DEC HL
def op_2B() {
  om_dec16(&HL);
}

// [2C] INC L
def op_2C() {
  om_inc8(L);
}

// [2D] DEC L
def op_2D() {
  om_dec8(L);
}

// [2E] LD L, n
def op_2E() {
  *A = mmu_next8();
}

// [2F] CPL
def op_2F() {
  *A ^= 0xFF;

  flag_set(FLAG_N, true);
  flag_set(FLAG_H, true);
}

// [30] JR NC, n
def op_30() {
  let n = mmu_next8();
  if not flag_get(FLAG_C) {
    om_jp(PC + uint16(n));
    cycles += 4;
  }
}

// [31] LD SP, nn
def op_31() {
  SP = mmu_next16();
}

// [32] LDD (HL), A
def op_32() {
  mmu_write8(HL, *A);
  HL -= 1;
}

// [33] INC SP
def op_33() {
  om_inc16(&SP);
}

// [34] INC (HL)
def op_34() {
  om_inc8(ram + HL);
}

// [35] DEC (HL)
def op_35() {
  om_dec8(ram + HL);
}

// [36] LD (HL), n
def op_36() {
  mmu_write8(HL, mmu_next8());
}

// [37] SCF
def op_37() {
  flag_set(FLAG_C, true);
  flag_set(FLAG_H, false);
  flag_set(FLAG_N, false);
}

// [38] JR C, n
def op_38() {
  let n = mmu_next8();
  if flag_get(FLAG_C) {
    om_jp(PC + uint16(n));
    cycles += 4;
  }
}

// [39] ADD HL, SP
def op_39() {
  HL = om_add16(HL, SP);
}

// [3A] LDD A, (HL)
def op_3A() {
  *A = mmu_read8(HL);
  HL -= 1;
}

// [3B] DEC SP
def op_3B() {
  om_dec16(&SP);
}

// [3C] INC A
def op_3C() {
  om_inc8(A);
}

// [3D] DEC A
def op_3D() {
  om_dec8(A);
}

// [3E] LD A, n
def op_3E() {
  *A = mmu_next8();
}

// [3F] CCF
def op_3F() {
  flag_set(FLAG_C, flag_geti(FLAG_C) ^ 1 != 0);
  flag_set(FLAG_H, false);
  flag_set(FLAG_N, false);
}

// [40] LD B, B
def op_40() {
  *B = *B;
}

// [41] LD B, C
def op_41() {
  *B = *C;
}

// [42] LD B, D
def op_42() {
  *B = *D;
}

// [43] LD B, E
def op_43() {
  *B = *E;
}

// [44] LD B, H
def op_44() {
  *B = *H;
}

// [45] LD B, L
def op_45() {
  *B = *L;
}

// [46] LD B, (HL)
def op_46() {
  *B = mmu_read8(HL);
}

// [47] LD B, A
def op_47() {
  *B = *A;
}

// [48] LD C, B
def op_48() {
  *C = *B;
}

// [49] LD C, C
def op_49() {
  *C = *C;
}

// [4A] LD C, D
def op_4A() {
  *C = *D;
}

// [4B] LD C, E
def op_4B() {
  *C = *E;
}

// [4C] LD C, H
def op_4C() {
  *C = *H;
}

// [4D] LD C, L
def op_4D() {
  *C = *L;
}

// [4E] LD C, (HL)
def op_4E() {
  *C = mmu_read8(HL);
}

// [4F] LD C, A
def op_4F() {
  *C = *A;
}

// [50] LD D, B
def op_50() {
  *D = *B;
}

// [51] LD D, C
def op_51() {
  *D = *C;
}

// [52] LD D, D
def op_52() {
  *D = *D;
}

// [53] LD D, E
def op_53() {
  *D = *E;
}

// [54] LD D, H
def op_54() {
  *D = *H;
}

// [55] LD D, L
def op_55() {
  *D = *L;
}

// [56] LD D, (HL)
def op_56() {
  *D = mmu_read8(HL);
}

// [57] LD D, A
def op_57() {
  *D = *A;
}

// [58] LD E, B
def op_58() {
  *E = *B;
}

// [59] LD E, C
def op_59() {
  *E = *C;
}

// [5A] LD E, D
def op_5A() {
  *E = *D;
}

// [5B] LD E, E
def op_5B() {
  *E = *E;
}

// [5C] LD E, H
def op_5C() {
  *E = *H;
}

// [5D] LD E, L
def op_5D() {
  *E = *L;
}

// [5E] LD E, (HL)
def op_5E() {
  *E = mmu_read8(HL);
}

// [5F] LD E, A
def op_5F() {
  *E = *A;
}

// [60] LD H, B
def op_60() {
  *H = *B;
}

// [61] LD H, C
def op_61() {
  *H = *C;
}

// [62] LD H, D
def op_62() {
  *H = *D;
}

// [63] LD H, E
def op_63() {
  *H = *E;
}

// [64] LD H, H
def op_64() {
  *H = *H;
}

// [65] LD H, L
def op_65() {
  *H = *L;
}

// [66] LD H, (HL)
def op_66() {
  *H = mmu_read8(HL);
}

// [67] LD H, A
def op_67() {
  *H = *A;
}

// [68] LD L, B
def op_68() {
  *L = *B;
}

// [69] LD L, C
def op_69() {
  *L = *C;
}

// [6A] LD L, D
def op_6A() {
  *L = *D;
}

// [6B] LD L, E
def op_6B() {
  *L = *E;
}

// [6C] LD L, H
def op_6C() {
  *L = *H;
}

// [6D] LD L, L
def op_6D() {
  *L = *L;
}

// [6E] LD L, (HL)
def op_6E() {
  *L = mmu_read8(HL);
}

// [6F] LD L, A
def op_6F() {
  *L = *A;
}

// [80] ADD A, B
def op_80() {
  *A = om_add8(*A, *B);
}

// [81] ADD A, C
def op_81() {
  *A = om_add8(*A, *C);
}

// [82] ADD A, D
def op_82() {
  *A = om_add8(*A, *C);
}

// [83] ADD A, E
def op_83() {
  *A = om_add8(*A, *E);
}

// [84] ADD A, H
def op_84() {
  *A = om_add8(*A, *H);
}

// [85] ADD A, L
def op_85() {
  *A = om_add8(*A, *L);
}

// [86] ADD A, (HL)
def op_86() {
  *A = om_add8(*A, mmu_read8(HL));
}

// [87] ADD A, A
def op_87() {
  *A = om_add8(*A, *A);
}

// [88] ADC A, B
def op_88() {
  *A = om_adc8(*A, *B);
}

// [89] ADC A, C
def op_89() {
  *A = om_adc8(*A, *C);
}

// [8A] ADC A, D
def op_8A() {
  *A = om_adc8(*A, *C);
}

// [8B] ADC A, E
def op_8B() {
  *A = om_adc8(*A, *E);
}

// [8C] ADC A, H
def op_8C() {
  *A = om_adc8(*A, *H);
}

// [8D] ADC A, L
def op_8D() {
  *A = om_adc8(*A, *L);
}

// [8E] ADC A, (HL)
def op_8E() {
  *A = om_adc8(*A, mmu_read8(HL));
}

// [8F] ADC A, A
def op_8F() {
  *A = om_adc8(*A, *A);
}

// [90] SUB A, B
def op_90() {
  *A = om_sub8(*A, *B);
}

// [91] SUB A, C
def op_91() {
  *A = om_sub8(*A, *C);
}

// [92] SUB A, D
def op_92() {
  *A = om_sub8(*A, *C);
}

// [93] SUB A, E
def op_93() {
  *A = om_sub8(*A, *E);
}

// [94] SUB A, H
def op_94() {
  *A = om_sub8(*A, *H);
}

// [95] SUB A, L
def op_95() {
  *A = om_sub8(*A, *L);
}

// [96] SUB A, (HL)
def op_96() {
  *A = om_sub8(*A, mmu_read8(HL));
}

// [97] SUB A, A
def op_97() {
  *A = om_sub8(*A, *A);
}

// [98] SBC A, B
def op_98() {
  *A = om_sbc8(*A, *B);
}

// [99] SBC A, C
def op_99() {
  *A = om_sbc8(*A, *C);
}

// [9A] SBC A, D
def op_9A() {
  *A = om_sbc8(*A, *C);
}

// [9B] SBC A, E
def op_9B() {
  *A = om_sbc8(*A, *E);
}

// [9C] SBC A, H
def op_9C() {
  *A = om_sbc8(*A, *H);
}

// [9D] SBC A, L
def op_9D() {
  *A = om_sbc8(*A, *L);
}

// [9E] SBC A, (HL)
def op_9E() {
  *A = om_sbc8(*A, mmu_read8(HL));
}

// [9F] SBC A, A
def op_9F() {
  *A = om_sbc8(*A, *A);
}

// [A0] AND A, B
def op_A0() {
  *A = om_and8(*A, *B);
}

// [A1] AND A, C
def op_A1() {
  *A = om_and8(*A, *C);
}

// [A2] AND A, D
def op_A2() {
  *A = om_and8(*A, *C);
}

// [A3] AND A, E
def op_A3() {
  *A = om_and8(*A, *E);
}

// [A4] AND A, H
def op_A4() {
  *A = om_and8(*A, *H);
}

// [A5] AND A, L
def op_A5() {
  *A = om_and8(*A, *L);
}

// [A6] AND A, (HL)
def op_A6() {
  *A = om_and8(*A, mmu_read8(HL));
}

// [A7] AND A, A
def op_A7() {
  *A = om_and8(*A, *A);
}

// [A8] XOR A, B
def op_A8() {
  *A = om_xor8(*A, *B);
}

// [A9] XOR A, C
def op_A9() {
  *A = om_xor8(*A, *C);
}

// [AA] XOR A, D
def op_AA() {
  *A = om_xor8(*A, *C);
}

// [AB] XOR A, E
def op_AB() {
  *A = om_xor8(*A, *E);
}

// [AC] XOR A, H
def op_AC() {
  *A = om_xor8(*A, *H);
}

// [AD] XOR A, L
def op_AD() {
  *A = om_xor8(*A, *L);
}

// [AE] XOR A, (HL)
def op_AE() {
  *A = om_xor8(*A, mmu_read8(HL));
}

// [AF] XOR A, A
def op_AF() {
  *A = om_xor8(*A, *A);
}

// [B0] OR A, B
def op_B0() {
  *A = om_or8(*A, *B);
}

// [B1] OR A, C
def op_B1() {
  *A = om_or8(*A, *C);
}

// [B2] OR A, D
def op_B2() {
  *A = om_or8(*A, *C);
}

// [B3] OR A, E
def op_B3() {
  *A = om_or8(*A, *E);
}

// [B4] OR A, H
def op_B4() {
  *A = om_or8(*A, *H);
}

// [B5] OR A, L
def op_B5() {
  *A = om_or8(*A, *L);
}

// [B6] OR A, (HL)
def op_B6() {
  *A = om_or8(*A, mmu_read8(HL));
}

// [B7] OR A, A
def op_B7() {
  *A = om_or8(*A, *A);
}

// [B8] CP A, B
def op_B8() {
  om_sub8(*A, *B);
}

// [B9] CP A, C
def op_B9() {
  om_sub8(*A, *C);
}

// [BA] CP A, D
def op_BA() {
  om_sub8(*A, *C);
}

// [BB] CP A, E
def op_BB() {
  om_sub8(*A, *E);
}

// [BC] CP A, H
def op_BC() {
  om_sub8(*A, *H);
}

// [BD] CP A, L
def op_BD() {
  om_sub8(*A, *L);
}

// [BE] CP A, (HL)
def op_BE() {
  om_sub8(*A, mmu_read8(HL));
}

// [BF] CP A, A
def op_BF() {
  om_sub8(*A, *A);
}

// [C0] RET NZ
def op_C0() {
  if not flag_get(FLAG_Z) {
    om_ret();
    cycles += 12;
  }
}

// [C1] POP BC
def op_C1() {
  om_pop16(&BC);
}

// [C2] JP NZ, nn
def op_C2() {
  let nn = mmu_next16();
  if not flag_get(FLAG_Z) {
    om_jp(nn);
    cycles += 4;
  }
}

// [C3] JP nn
def op_C3() {
  om_jp(mmu_next16());
}

// [C4] CALL NZ, nn
def op_C4() {
  let nn = mmu_next16();
  if not flag_get(FLAG_Z) {
    om_call(nn);
    cycles += 12;
  }
}

// [C5] PUSH BC
def op_C5() {
  om_push16(&BC);
}

// [C6] ADD A, n
def op_C6() {
  *A = om_add8(*A, mmu_next8());
}

// [C7] RST $00
def op_C7() {
  om_jp(0x00);
}

// [C8] RET Z
def op_C8() {
  if flag_get(FLAG_Z) {
    om_ret();
    cycles += 12;
  }
}

// [C9] RET
def op_C9() {
  om_ret();
}

// [CA] JP Z, nn
def op_CA() {
  let nn = mmu_next16();
  if flag_get(FLAG_Z) {
    om_jp(nn);
    cycles += 4;
  }
}

// [CB] ~
def op_CB() {
  // Get next opcode
  let opcode = mmu_next8();

  // Not implemented yet
  printf("error: unknown opcode: $CB $%02X\n", opcode);
  exit(-1);
}

// [CC] CALL Z, nn
def op_CC() {
  let nn = mmu_next16();
  if flag_get(FLAG_Z) {
    om_call(nn);
    cycles += 12;
  }
}

// [CD] CALL nn
def op_CD() {
  om_call(mmu_next16());
}

// [CE] ADC A, n
def op_CE() {
  *A = om_adc8(*A, mmu_next8());
}

// [CF] RST $08
def op_CF() {
  om_jp(0x08);
}

// [D5] PUSH DE
def op_D5() {
  om_push16(&DE);
}

// [DF] RST $18
def op_DF() {
  om_jp(0x18);
}

// [E0] LD ($FF00 + n), A
def op_E0() {
  mmu_write8(0xFF00 + uint16(mmu_next8()), *A);
}

// [E1] POP HL
def op_E1() {
  om_pop16(&HL);
}

// [E2] LD ($FF00 + C), A
def op_E2() {
  mmu_write8(0xFF00 + uint16(*C), *A);
}

// [E5] PUSH HL
def op_E5() {
  om_push16(&HL);
}

// [E6] AND n
def op_E6() {
  *A = om_and8(*A, mmu_next8());
}

// [E7] RST $20
def op_E7() {
  om_jp(0x20);
}

// [E8] ADD SP, n
def op_E8() {
  SP = om_add16(SP, uint16(mmu_next8()));
}

// [E9] JP (HL)
def op_E9() {
  om_jp(HL);
}

// [EA] LD (nn), A
def op_EA() {
  mmu_write8(mmu_next16(), *A);
}

// [EE] XOR n
def op_EE() {
  *A = om_xor8(*A, mmu_next8());
}

// [EF] RST $28
def op_EF() {
  om_jp(0x28);
}

// [F0] LD A, ($FF00 + n)
def op_F0() {
  *A = mmu_read8(0xFF00 + uint16(mmu_next8()));
}

// [F1] POP AF
def op_F1() {
  om_pop16(&AF);
}

// [F2] LD A, ($FF00 + C)
def op_F2() {
  *A = mmu_read8(0xFF00 + uint16(*C));
}

// [F3] DI
def op_F3() {
  IME = false;
}

// [F5] PUSH AF
def op_F5() {
  om_push16(&AF);
}

// [F6] OR n
def op_F6() {
  *A = om_or8(*A, mmu_next8());
}

// [F7] RST 30H
def op_F7() {
  om_jp(0x30);
}

// TODO: [F8] LD HL, SP +/- n

// [F9] LD SP, HL
def op_F8() {
  SP = HL;
}

// [FA] LD A, (nn)
def op_FA() {
  *A = mmu_read8(mmu_next16());
}

// [FB] EI
def op_FB() {
  IME = true;
}

// [FE] CP n
def op_FE() {
  om_sub8(*A, mmu_next8());
}

// [FF] RST $38
def op_FF() {
  om_jp(0x38);
}

// =============================================================================
// [EX] Execute
// =============================================================================
def execute() {
  // Get next opcode
  let opcode = mmu_next8();

  // Check if valid/known instruction
  if *((optable as *int64) + opcode) == 0 {
    printf("error: unknown opcode: $%02X\n", opcode);
    exit(-1);
  }

  // Execute instruction
  (*(optable + opcode))();

  // DEBUG: Log opcode
  // TODO: Better debug information
  printf("debug: opcode: $%02X\n", opcode);

  // DEBUG: Log registers
  printf("debug: r: PC=%04X SP=%04X AF=%04X BC=%04X DE=%04X HL=%04X\n",
    PC,
    SP,
    AF,
    BC,
    DE,
    HL
  );

  // Add instruction execution time to cycle counter
  cycles += float64(*(cycletable + opcode));
}
