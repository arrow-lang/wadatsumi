
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

  open_rom("./boxxle.gb");

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

  // DEBUG: Log opcode
  // TODO: Better debug information
  printf("debug: opcode: $%02X\n", opcode);

  // Execute instruction
  (*(optable + opcode))();

  // Add instruction execution time to cycle counter
  cycles += float64(*(cycletable + opcode));
}
