
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
let A: *uint8 = &AF as *uint8;
let BC: uint16 = 0;
let DE: uint16 = 0;
let HL: uint16 = 0;
let SP: uint16 = 0;

def main() {
  init();
  open_rom("./boxxle.gb");

  while true { emulate(); }

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

def readNext8(): uint8 {
  let value = *(ram + PC);
  // TODO: `+=`
  PC = PC + 1;

  return value;
}

def readNext16(): uint16 {
  let l = readNext8();
  let h = readNext8();
  return uint16(l) | (uint16(h) * 256);
}

def emulate() {
  // Get next opcode
  let opcode = readNext8();

  // TODO: Jump table / 1st-class functions
  // *(op + opcode)();

  if opcode == 0x00 {
    // NOP
  } else if opcode == 0x01 {
    // LD BC, nn – Set BC to the immediate 8-bit value
    BC = readNext16();
  } else if opcode == 0x11 {
    // LD DE, nn – Set DE to the immediate 8-bit value
    DE = readNext16();
  } else if opcode == 0x21 {
    // LD HL, nn – Set HL to the immediate 8-bit value
    HL = readNext16();
  } else if opcode == 0x3E {
    // LD A, nn – Set A to the immediate 8-bit value
    *A = readNext8();
  } else if opcode == 0xC3 {
    // JP – Set PC to the immediate 16-bit value
    PC = readNext16();
  } else if opcode == 0xEA {
    // LD (nn), A – Set (nn) to A
    readNext16();
    // BUG: *(ram + readNext16()) = *A;
  } else {
    printf("error: unknown opcode: 0x%02X\n", opcode);
    exit(1);
  }
}
