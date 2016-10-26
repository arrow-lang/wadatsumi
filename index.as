
// libc
type size_t = int64;
type FILE = int64;
type c_long = int64;
type c_int = int32;

extern def exit(status: c_int);
extern def printf(format: str, ...);
extern def malloc(s: size_t): *uint8;
extern def free(ptr: *uint8);
extern def fopen(filename: str, mode: str): *FILE;
extern def fclose(stream: *FILE);
extern def fread(buffer: *uint8, size: size_t, count: size_t, stream: *FILE): size_t;
extern def fseek(stream: *FILE, offset: c_long, origin: c_int): c_int;
extern def ftell(stream: *FILE): c_int;
extern def strncpy(dst: str, src: str, count: size_t): str;

// CPU
let ram: *uint8;
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

  open_rom("./boxxle.gb");

  while true { emulate(); }

  fini_optable();
  fini();
}

main();

def init() {
  ram = malloc(0x10000);
  reset();
}

def reset() {
  PC = 0x0100;
  AF = 0x01B0;
  BC = 0x0013;
  DE = 0x00D8;
  HL = 0x014D;
  SP = 0xFFFE;
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

def execute() {
  // Get next opcode
  let opcode = mmu_next8();

  // Decode and execute instruction
  *(optable + opcode)();
}

// =============================================================================
// [MMU] Memory Management Unit
// =============================================================================

// Read 8-bits
def mmu_read8(address: uint16): uint8 {
  return *(ram + address);
}

// Read 16-bits
def mmu_read16(address: uint16): uint8 {
  let l = mmu_read8(address + 0);
  let h = mmu_read8(address + 1);

  return uint16(l) | (uint16(h) * 256);
}

// Read IMMEDIATE 8-bits
def mmu_next8(): uint8 {
  let value = mmu_read8(PC);
  PC += 1;

  return value;
}

// Read IMMEDIATE 16-bits
def mmu_next16(): uint8 {
  let value = mmu_read16(PC);
  PC += 1;

  return value;
}

// Write 8-bits
def mmu_write8(address: uint16, value: uint8): uint8 {
}

// Write 16-bits
def mmu_write16(address: uint16, value: uint16): uint8 {
}

// =============================================================================
// [OT] Operation Table
// =============================================================================
let optable: *(() -> ());

def init_optable() {
  optable = malloc(0x1_00) as *(() -> ());

  *(optable + 0x00) = op_00;
  *(optable + 0x01) = op_01;
  *(optable + 0x02) = op_02;
  *(optable + 0x03) = op_03;
  *(optable + 0x04) = op_04;
  *(optable + 0x05) = op_05;
  *(optable + 0x06) = op_06;
  *(optable + 0x07) = op_07;
  *(optable + 0x08) = op_08;
  *(optable + 0x09) = op_09;
  *(optable + 0x0A) = op_0A;
  *(optable + 0x0B) = op_0B;
  *(optable + 0x0C) = op_0C;
  *(optable + 0x0D) = op_0D;
  *(optable + 0x0E) = op_0E;
  *(optable + 0x0F) = op_0F;
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
}

def fini_cycletable() {
  free(cycletable as *uint8);
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
  *BC += 1;

  flag_set(FLAG_Z, *BC == 0);
  flag_set(FLAG_N, 0);
  flag_set(FLAG_H, ..);
}

// [04] INC B
def op_04() {
  *B += 1;
  // TODO: Flags
}

// [05] DEC B
def op_05() {
  *B -= 1;
  // TODO: Flags
}


// [06]
// [07]
// [08]
// [09]
// [0A]
// [0B]
// [0C]
// [0D]
// [0E]
// [0F]
