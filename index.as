
// libc
type size_t = int64;
type FILE = int64;
type c_long = int64;
type c_int = int32;

extern def exit(status: c_int);
extern def printf(format: str, ...);
extern def fprintf(stream: *FILE, format: str, ...);
extern def malloc(s: size_t): *uint8;
extern def memset(dst: *uint8, ch: c_int, count: size_t): *uint8;
extern def memcpy(dst: *uint8, src: *uint8, count: size_t): *uint8;

extern def qsort(ptr: *uint8, count: size_t, size: size_t, comp: (*uint8, *uint8) -> c_int);

extern def free(ptr: *uint8);
extern def fopen(filename: str, mode: str): *FILE;
extern def fclose(stream: *FILE);
extern def fwrite(ptr: *uint8, size: size_t, count: size_t, stream: *FILE);
extern def fread(buffer: *uint8, size: size_t, count: size_t, stream: *FILE): size_t;
extern def fseek(stream: *FILE, offset: c_long, origin: c_int): c_int;
extern def ftell(stream: *FILE): c_int;
extern def fflush(stream: *FILE);
extern def strncpy(dst: str, src: str, count: size_t): str;
extern def clock(): uint64;
extern def rand(): c_int;
extern def sleep(seconds: uint32);

let CLOCKS_PER_SEC: uint64 = 1000000;

// Timers
let DIV: uint16 = 0xABCC;
let TIMA: uint8 = 0;
let TMA: uint8 = 0;
let TAC: uint8 = 0;

// Memory
let rom: *uint8;    // ROM – as big as cartridge
let vram: *uint8;   // Video RAM – 8 KiB
let wram: *uint8;   // Work RAM – 8 KiB
let oam: *uint8;    // Sprite Attribute Table (OAM) – 160 B
let hram: *uint8;   // High RAM – 127 B
let eram: *uint8;   // External RAM – (defined by cart)

// CPU: State
let is_running = true;
let CYCLES: uint8;
let IME = false;
let IME_pending = false;
let PC: uint16 = 0;
let IE: uint8;
let IF: uint8;
let HALT = false;

// CPU: Registers
let AF: uint16 = 0;
let A: *uint8 = (&AF as *uint8) + 1;
let F: *uint8 = (&AF as *uint8) + 0;
let BC: uint16 = 0;
let B: *uint8 = (&BC as *uint8) + 1;
let C: *uint8 = (&BC as *uint8) + 0;
let DE: uint16 = 0;
let D: *uint8 = (&DE as *uint8) + 1;
let E: *uint8 = (&DE as *uint8) + 0;
let HL: uint16 = 0;
let H: *uint8 = (&HL as *uint8) + 1;
let L: *uint8 = (&HL as *uint8) + 0;
let SP: uint16 = 0;

def main(argc: int32, argv: *str, environ: *str) {
  init();

  open_rom(*(argv + 1));

  dump_rom();

  reset();

  execute();

  fini();
}

def init() {
  sdl_init();

  cpu_init();
  gpu_init();

  init_optable();
  init_cycletable();
}

def reset() {
  mmu_reset();
  joy_reset();
  gpu_reset();
  cpu_reset();
}

def fini() {
  sdl_fini();

  cpu_fini();
  gpu_fini();

  fini_optable();
  fini_cycletable();

  // Free ROM
  if rom != 0 as *uint8 {
    free(rom);
  }
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

  // Free ROM (if needed)
  if rom != 0 as *uint8 {
    free(rom);
  }

  // Free External ROM (if needed)
  if eram != 0 as *uint8 {
    free(eram);
  }

  // Allocate space in ROM
  rom = malloc(length);

  // Read file into ROM
  fread(rom, 1, length, stream);

  // Allocate space in external RAM
  let eram_size = rom_get_ext_ram_size();
  if eram_size > 0 {
    eram = malloc(size_t(eram_size));

    // Zero out space
    memset(eram, 0, size_t(eram_size));
  }
}

def rom_get_ext_ram_size(): uint16 {
  let ext_ram_size_code = *(rom + 0x149);

  return (if ext_ram_size_code == 0x01 {
    2;
  } else if ext_ram_size_code == 0x02 {
    8;
  } else if ext_ram_size_code == 0x03 {
    32;
  } else {
    0;
  }) * 1024;
}

def dump_rom() {
  // Gather ROM information
  // Title
  let rom_title = malloc(16) as str;
  strncpy(rom_title, (rom + 0x134) as str, 16);

  // Licensee
  let licensee = *(rom + 0x14B);
  if licensee == 0x33 {
    let licensee_0 = *(rom + 0x0144);
    let licensee_1 = *(rom + 0x0145);

    printf("warn: unexpected (new) licensee code: %02X %02X\n", licensee_0, licensee_1);
  }

  // CGB Flag
  let cgb_mode = *(rom + 0x143);

  // SGB Flag
  let is_sgb = *(rom + 0x146) == 0x03;

  // Cartridge Type
  let cart = *(rom + 0x147);

  // ROM Size
  let rom_size = (32 * 1024) << *(rom + 0x148);

  // External RAM Size
  let ext_ram_size = rom_get_ext_ram_size();

  // Destination Code
  let dst_code = *(rom + 0x014A);

  // ROM Version
  let rom_version = *(rom + 0x14C);

  // DEBUG: Print out Cartridge
  printf("%-20s : %s\n", "Title", rom_title);
  printf("%-20s : %02X\n", "Licensee", licensee);
  printf("%-20s : %d\n", "SGB", is_sgb);

  if cgb_mode == 0x80 {
    printf("%-20s : %s\n", "CGB", "compatible");
  } else if cgb_mode == 0xC0 {
    printf("%-20s : %s\n", "CGB", "require");
  } else {
    printf("%-20s : %s\n", "CGB", "no");
  }

  printf("%-20s : %02X\n", "Cartridge", cart);
  printf("%-20s : %d\n", "ROM Size", rom_size);
  printf("%-20s : %d\n", "External RAM Size", ext_ram_size);
  printf("%-20s : %d\n", "Destination", dst_code);
  printf("%-20s : %d\n", "Version", rom_version);
  printf("\n");

  free(rom_title as *uint8);

  // Fail if we can't support
  if cgb_mode == 0xC0 {
    printf("error: ROM requires CGB (which is not implemented)\n");
    exit(1);
  }
}

// =============================================================================
// [X] Helpers
// =============================================================================

def bit(value: bool, n: uint8): uint8 {
  return (if value { 1; } else { 0; }) << n;
}

def testb(value: uint8, n: uint8): bool {
  return (value & (1 << n)) != 0;
}

// =============================================================================
// [MMU] Memory Management Unit
// =============================================================================

let mmu_mapper: uint8;

let MM_NONE: uint8 = 0;
let MM_MBC1: uint8 = 1;

let mmu_mapper_read8: (uint16, *uint8) -> bool;
let mmu_mapper_write8: (uint16, uint8) -> bool;

// TODO: What does this start at?
let mmu_mbc1_rom_bank: uint8 = 0x01;
let mmu_mbc1_ram_bank: uint8 = 0x00;
let mmu_mbc1_ram_enable = false;
let mmu_mbc1_mode: uint8 = 0x00;

def mmu_reset() {
  // Get cartridge type
  let cart = *(rom + 0x147);
  if cart == 0x00 {
    mmu_mapper = MM_NONE;
    mmu_mapper_read8 = mmu_none_read8;
    mmu_mapper_write8 = mmu_none_write8;
  } else if cart == 0x01 or cart == 0x02 or cart == 0x03 {
    mmu_mapper = MM_MBC1;
    mmu_mapper_read8 = mmu_mbc1_read8;
    mmu_mapper_write8 = mmu_mbc1_write8;
  } else {
    printf("error: unsupported memory bank controller: %02X\n", cart);
  }
}

def mmu_none_read8(address: uint16, ptr: *uint8): bool {
  // ROM: $0000 – $7FFF
  if (address & 0xF000) <= 0x7000 {
    *ptr = *(rom + address);

    return true;
  }

  return false;
}

def mmu_none_write8(address: uint16, value: uint8): bool {
  // ROM: $0000 – $7FFF
  if (address & 0xF000) <= 0x7000 {
    // Deny all writes (but declare them handled)
    return true;
  }

  return false;
}

def mmu_mbc1_read8(address: uint16, ptr: *uint8): bool {
  if address <= 0x3FFF {
    // This area always contains the first 16KBytes of the cartridge ROM.
    *ptr = *(rom + address);
  } else if address <= 0x7FFF {
    // This area may contain any of the further 16KByte banks of the ROM,
    // allowing to address up to 125 ROM Banks (almost 2MByte).
    *ptr = *(rom + (uint64(mmu_mbc1_rom_bank) * 0x4000) + (uint64(address) - 0x4000));
  } else if address >= 0xA000 and address <= 0xBFFF {
    // External RAM
    let eram_size = rom_get_ext_ram_size();
    let offset = address - 0xA000;
    if mmu_mbc1_ram_enable and offset < eram_size {
      *ptr = *((eram + (uint64(mmu_mbc1_ram_bank) * 0x2000)) + offset);
    } else {
      // External RAM is not enabled
      *ptr = 0xFF;
    }
  } else {
    // Unhandled
    return false;
  }

  return true;
}

def mmu_mbc1_write8(address: uint16, value: uint8): bool {
  // TODO: If RAM Bank Number / ROM Bank Number were calculated from
  //       the two registers it'd make this code cleaner

  if address <= 0x1FFF {
    // RAM Enable
    mmu_mbc1_ram_enable = (value & 0x0A) != 0;
  } else if address <= 0x3FFF {
    // ROM Bank Number (lower 5 bits)
    mmu_mbc1_rom_bank &= ~0x1F;
    mmu_mbc1_rom_bank |= (value & 0x1F);

    // Selecting an invalid bank will bump you up a bank
    let n = (mmu_mbc1_rom_bank & 0x1F);
    if n == 0x20 or n == 0x40 or n == 0x60 or n == 0x00 {
      mmu_mbc1_rom_bank += 1;
    }
  } else if address <= 0x5FFF {
    // RAM Bank Number OR Upper 2 bits of ROM Bank Number
    if mmu_mbc1_mode == 0x00 {
      mmu_mbc1_ram_bank = value & 0x3;
    } else if mmu_mbc1_mode == 0x01 {
      mmu_mbc1_rom_bank &= ~0x60;
      mmu_mbc1_rom_bank |= (value & 0x3) << 5;
    }
  } else if address <= 0x7FFF {
    // ROM/RAM Mode Select
    let mode = value & 0x1;
    if mode != mmu_mbc1_mode {
      if mode == 0x00 {
        let tmp = (mmu_mbc1_rom_bank & 0x60) >> 5;
        mmu_mbc1_rom_bank &= ~0x60;
        mmu_mbc1_ram_bank = tmp;
      } else if mode == 0x01 {
        let tmp = mmu_mbc1_ram_bank;
        mmu_mbc1_ram_bank = 0x00;
        mmu_mbc1_rom_bank &= ~0x60;
        mmu_mbc1_rom_bank |= (tmp & 0x3) << 5;
      }
    }
  } else if address >= 0xA000 and address <= 0xBFFF {
    // External RAM
    let eram_size = uint64(rom_get_ext_ram_size());
    let offset = uint64(address) - 0xA000;
    if mmu_mbc1_ram_enable and offset < eram_size {
      *((eram + (uint64(mmu_mbc1_ram_bank) * 0x2000)) + offset) = value;
    }
  } else {
    // Unhandled
    return false;
  }

  return true;
}

// Read 8-bits
def mmu_read8(address: uint16): uint8 {
  // Check with memory bank controller if it handles this address
  let rv: uint8;
  if mmu_mapper_read8(address, &rv) {
    return rv;
  }

  // Video RAM: $8000 – $9FFF
  if (address & 0xF000) <= 0x9000 {
    // VRAM cannot be accessed in mode 3
    // let mode = mmu_read8(0xFF41) & 3;
    // if mode == 3 { return 0xFF; }

    return *(vram + (address & 0x1FFF));
  }

  // Work RAM: $C000 – $DFFF
  // ECHO (of Work RAM): $E000 – $FDFF
  if (address & 0xF000) <= 0xD000 or address <= 0xFDFF {
    return *(wram + (address & 0x1FFF));
  }

  // Sprite Attribute Table (OAM): $FE00 – $FE9F
  if (address >= 0xFE00) and (address <= 0xFE9F) {
    // OAM cannot be accessed in modes 2 or 3
    // let mode = mmu_read8(0xFF41) & 3;
    // if mode == 3 or mode == 2 { return 0xFF; }

    return *(oam + (address & 0xFF));
  }

  // Unusable
  if (address <= 0xFEFF) {
    // Not connected to anything
    return 0xFF;
  }

  // High RAM (HRAM): $FF80 – $FFFE
  if (address >= 0xFF80 and address <= 0xFFFE) {
    return *(hram + ((address & 0xFF) - 0x80));
  }

  // Sound Register
  if (
    (address >= 0xFF10 and address <= 0xFF14) or
    (address >= 0xFF16 and address <= 0xFF1E) or
    (address >= 0xFF20 and address <= 0xFF26) or
    (address >= 0xFF30 and address <= 0xFF3F)
  ) {
    return sound_read(address);
  }

  // I/O Ports

  if address == 0xFF00 {
    return joy_read(address);
  }

  if (address & 0xF0) >= 0x40 and (address & 0xF0) <= 0x70 {
    // GPU Register
    return gpu_read(address);
  }

  if address == 0xFF0F {
    // IF – Interrupt Flag (R/W)
    // NOTE: Unused bits are 1 in this register because who the fuck knows
    return IF | 0xE0;
  } else if address == 0xFFFF {
    // IE – Interrupt Enable (R/W)
    return IE | 0xE0;
  }

  if address == 0xFF04 {
    return uint8(((DIV & 0xFF00) >> 8));
  }

  if address == 0xFF05 {
    // printf("warn: timer read");
    return TIMA;
  }

  if address == 0xFF06 {
    // printf("warn: TMA read");
    return TMA;
  }

  if address == 0xFF07 {
    // printf("warn: TAC read");
    return TAC;
  }

  printf("warn: unhandled read from memory: $%04X\n", address);
  return 0xFF;
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
  PC += 2;

  return value;
}

// Write 8-bits
def mmu_write8(address: uint16, value: uint8) {
  // Check with memory bank controller if it handles this address
  if mmu_mapper_write8(address, value) {
    return;
  }

  // Video RAM: $8000 – $9FFF
  if (address & 0xF000) <= 0x9000 {
    // FIXME: VRAM cannot be accessed in mode 3
    // let mode = mmu_read8(0xFF41) & 3;
    // if gpu_lcd_enable and mode == 3 { return; }

    // GPU VRAM
    *(vram + (address & 0x1FFF)) = value;

    return;
  }

  // Work RAM: $C000 – $DFFF
  // ECHO (of Work RAM): $E000 – $FDFF
  if (address & 0xF000) <= 0xD000 or address <= 0xFDFF {
    // WRAM
    *(wram + (address & 0x1FFF)) = value;
    return;
  }

  // Sprite Attribute Table (OAM): $FE00 – $FE9F
  if (address >= 0xFE00) and (address <= 0xFE9F) {
    // FIXME: OAM cannot be accessed in modes 2 or 3
    // let mode = mmu_read8(0xFF41) & 3;
    // if gpu_lcd_enable and (mode == 3 or mode == 2) { return; }

    *(oam + (address & 0xFF)) = value;
    return;
  }

  // Unusable
  if (address <= 0xFEFF) {
    // Not connected to anything
    return;
  }

  // High RAM (HRAM): $FF80 – $FFFE
  if (address >= 0xFF80 and address <= 0xFFFE) {
    // HRAM
    *(hram + ((address & 0xFF) - 0x80)) = value;
    return;
  }

  if address == 0xFF00 {
    joy_write(address, value);
    return;
  }

  // GPU Register
  if (address & 0xF0) >= 0x40 and (address & 0xF0) <= 0x70 {
    gpu_write(address, value);
    return;
  }

  // Sound Register
  if (
    (address >= 0xFF10 and address <= 0xFF14) or
    (address >= 0xFF16 and address <= 0xFF1E) or
    (address >= 0xFF20 and address <= 0xFF26) or
    (address >= 0xFF30 and address <= 0xFF3F)
  ) {
    sound_write(address, value);
    return;
  }

  // SB – Serial Transfer Data (R/W)
  // SC – Serial Transfer Control (R/W)
  if (address == 0xFF01 or address == 0xFF02) {
    // TODO: Implement link cable / debug printout
    printf("LINK CABLE\n");
    return;
  }

  // IF – Interrupt Flag (R/W)
  if (address == 0xFF0F) {
    IF = value & 0x1F;
    return;
  }

  // IE – Interrupt Enable (R/W)
  if (address == 0xFFFF) {
    IE = value & 0x1F;
    return;
  }

  if (
    (address == 0xFF04) or
    (address == 0xFF05) or
    (address == 0xFF06) or
    (address == 0xFF07)
  ) {
    timer_write(address, value);
    return;
  }

  printf("warn: unhandled write to memory: $%04X ($%02X)\n", address, value);
  // exit(-1);
}

// Write 16-bits
def mmu_write16(address: uint16, value: uint16) {
  mmu_write8(address + 0, uint8(value & 0xFF));
  mmu_write8(address + 1, uint8(value >> 8));
}

// =============================================================================
// [OT] Operation Table
// =============================================================================
let optable: *(() -> ());
let optable_CB: *(() -> ());

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
  *(optable + 0x07) = op_07;
  *(optable + 0x08) = op_08;
  *(optable + 0x09) = op_09;
  *(optable + 0x0A) = op_0A;
  *(optable + 0x0B) = op_0B;
  *(optable + 0x0C) = op_0C;
  *(optable + 0x0D) = op_0D;
  *(optable + 0x0E) = op_0E;
  *(optable + 0x0F) = op_0F;

  *(optable + 0x10) = op_10;
  *(optable + 0x11) = op_11;
  *(optable + 0x12) = op_12;
  *(optable + 0x13) = op_13;
  *(optable + 0x14) = op_14;
  *(optable + 0x15) = op_15;
  *(optable + 0x16) = op_16;
  *(optable + 0x17) = op_17;
  *(optable + 0x18) = op_18;
  *(optable + 0x19) = op_19;
  *(optable + 0x1A) = op_1A;
  *(optable + 0x1B) = op_1B;
  *(optable + 0x1C) = op_1C;
  *(optable + 0x1D) = op_1D;
  *(optable + 0x1E) = op_1E;
  *(optable + 0x1F) = op_1F;

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

  *(optable + 0x70) = op_70;
  *(optable + 0x71) = op_71;
  *(optable + 0x72) = op_72;
  *(optable + 0x73) = op_73;
  *(optable + 0x74) = op_74;
  *(optable + 0x75) = op_75;
  *(optable + 0x76) = op_76;
  *(optable + 0x77) = op_77;
  *(optable + 0x78) = op_78;
  *(optable + 0x79) = op_79;
  *(optable + 0x7A) = op_7A;
  *(optable + 0x7B) = op_7B;
  *(optable + 0x7C) = op_7C;
  *(optable + 0x7D) = op_7D;
  *(optable + 0x7E) = op_7E;
  *(optable + 0x7F) = op_7F;

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

  *(optable + 0xD0) = op_D0;
  *(optable + 0xD1) = op_D1;
  *(optable + 0xD2) = op_D2;
  // *(optable + 0xD3) = _
  *(optable + 0xD4) = op_D4;
  *(optable + 0xD5) = op_D5;
  *(optable + 0xD6) = op_D6;
  *(optable + 0xD7) = op_D7;
  *(optable + 0xD8) = op_D8;
  *(optable + 0xD9) = op_D9;
  *(optable + 0xDA) = op_DA;
  // *(optable + 0xDB) = _
  *(optable + 0xDC) = op_DC;
  // *(optable + 0xDD) = _
  *(optable + 0xDE) = op_DE;
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
  *(optable + 0xF9) = op_F9;
  *(optable + 0xFA) = op_FA;
  *(optable + 0xFB) = op_FB;
  // *(optable + 0xFC) = _
  // *(optable + 0xFD) = _
  *(optable + 0xFE) = op_FE;
  *(optable + 0xFF) = op_FF;

  optable_CB = malloc(0x1_00 * 8) as *(() -> ());
  memset(optable_CB as *uint8, 0, 0x1_00 * 8);

  *(optable_CB + 0x00) = op_CB_00;
  *(optable_CB + 0x01) = op_CB_01;
  *(optable_CB + 0x02) = op_CB_02;
  *(optable_CB + 0x03) = op_CB_03;
  *(optable_CB + 0x04) = op_CB_04;
  *(optable_CB + 0x05) = op_CB_05;
  *(optable_CB + 0x06) = op_CB_06;
  *(optable_CB + 0x07) = op_CB_07;
  *(optable_CB + 0x08) = op_CB_08;
  *(optable_CB + 0x09) = op_CB_09;
  *(optable_CB + 0x0A) = op_CB_0A;
  *(optable_CB + 0x0B) = op_CB_0B;
  *(optable_CB + 0x0C) = op_CB_0C;
  *(optable_CB + 0x0D) = op_CB_0D;
  *(optable_CB + 0x0E) = op_CB_0E;
  *(optable_CB + 0x0F) = op_CB_0F;

  *(optable_CB + 0x10) = op_CB_10;
  *(optable_CB + 0x11) = op_CB_11;
  *(optable_CB + 0x12) = op_CB_12;
  *(optable_CB + 0x13) = op_CB_13;
  *(optable_CB + 0x14) = op_CB_14;
  *(optable_CB + 0x15) = op_CB_15;
  *(optable_CB + 0x16) = op_CB_16;
  *(optable_CB + 0x17) = op_CB_17;
  *(optable_CB + 0x18) = op_CB_18;
  *(optable_CB + 0x19) = op_CB_19;
  *(optable_CB + 0x1A) = op_CB_1A;
  *(optable_CB + 0x1B) = op_CB_1B;
  *(optable_CB + 0x1C) = op_CB_1C;
  *(optable_CB + 0x1D) = op_CB_1D;
  *(optable_CB + 0x1E) = op_CB_1E;
  *(optable_CB + 0x1F) = op_CB_1F;

  *(optable_CB + 0x20) = op_CB_20;
  *(optable_CB + 0x21) = op_CB_21;
  *(optable_CB + 0x22) = op_CB_22;
  *(optable_CB + 0x23) = op_CB_23;
  *(optable_CB + 0x24) = op_CB_24;
  *(optable_CB + 0x25) = op_CB_25;
  *(optable_CB + 0x26) = op_CB_26;
  *(optable_CB + 0x27) = op_CB_27;
  *(optable_CB + 0x28) = op_CB_28;
  *(optable_CB + 0x29) = op_CB_29;
  *(optable_CB + 0x2A) = op_CB_2A;
  *(optable_CB + 0x2B) = op_CB_2B;
  *(optable_CB + 0x2C) = op_CB_2C;
  *(optable_CB + 0x2D) = op_CB_2D;
  *(optable_CB + 0x2E) = op_CB_2E;
  *(optable_CB + 0x2F) = op_CB_2F;

  *(optable_CB + 0x30) = op_CB_30;
  *(optable_CB + 0x31) = op_CB_31;
  *(optable_CB + 0x32) = op_CB_32;
  *(optable_CB + 0x33) = op_CB_33;
  *(optable_CB + 0x34) = op_CB_34;
  *(optable_CB + 0x35) = op_CB_35;
  *(optable_CB + 0x36) = op_CB_36;
  *(optable_CB + 0x37) = op_CB_37;
  *(optable_CB + 0x38) = op_CB_38;
  *(optable_CB + 0x39) = op_CB_39;
  *(optable_CB + 0x3A) = op_CB_3A;
  *(optable_CB + 0x3B) = op_CB_3B;
  *(optable_CB + 0x3C) = op_CB_3C;
  *(optable_CB + 0x3D) = op_CB_3D;
  *(optable_CB + 0x3E) = op_CB_3E;
  *(optable_CB + 0x3F) = op_CB_3F;

  *(optable_CB + 0x40) = op_CB_40;
  *(optable_CB + 0x41) = op_CB_41;
  *(optable_CB + 0x42) = op_CB_42;
  *(optable_CB + 0x43) = op_CB_43;
  *(optable_CB + 0x44) = op_CB_44;
  *(optable_CB + 0x45) = op_CB_45;
  *(optable_CB + 0x46) = op_CB_46;
  *(optable_CB + 0x47) = op_CB_47;
  *(optable_CB + 0x48) = op_CB_48;
  *(optable_CB + 0x49) = op_CB_49;
  *(optable_CB + 0x4A) = op_CB_4A;
  *(optable_CB + 0x4B) = op_CB_4B;
  *(optable_CB + 0x4C) = op_CB_4C;
  *(optable_CB + 0x4D) = op_CB_4D;
  *(optable_CB + 0x4E) = op_CB_4E;
  *(optable_CB + 0x4F) = op_CB_4F;

  *(optable_CB + 0x50) = op_CB_50;
  *(optable_CB + 0x51) = op_CB_51;
  *(optable_CB + 0x52) = op_CB_52;
  *(optable_CB + 0x53) = op_CB_53;
  *(optable_CB + 0x54) = op_CB_54;
  *(optable_CB + 0x55) = op_CB_55;
  *(optable_CB + 0x56) = op_CB_56;
  *(optable_CB + 0x57) = op_CB_57;
  *(optable_CB + 0x58) = op_CB_58;
  *(optable_CB + 0x59) = op_CB_59;
  *(optable_CB + 0x5A) = op_CB_5A;
  *(optable_CB + 0x5B) = op_CB_5B;
  *(optable_CB + 0x5C) = op_CB_5C;
  *(optable_CB + 0x5D) = op_CB_5D;
  *(optable_CB + 0x5E) = op_CB_5E;
  *(optable_CB + 0x5F) = op_CB_5F;

  *(optable_CB + 0x60) = op_CB_60;
  *(optable_CB + 0x61) = op_CB_61;
  *(optable_CB + 0x62) = op_CB_62;
  *(optable_CB + 0x63) = op_CB_63;
  *(optable_CB + 0x64) = op_CB_64;
  *(optable_CB + 0x65) = op_CB_65;
  *(optable_CB + 0x66) = op_CB_66;
  *(optable_CB + 0x67) = op_CB_67;
  *(optable_CB + 0x68) = op_CB_68;
  *(optable_CB + 0x69) = op_CB_69;
  *(optable_CB + 0x6A) = op_CB_6A;
  *(optable_CB + 0x6B) = op_CB_6B;
  *(optable_CB + 0x6C) = op_CB_6C;
  *(optable_CB + 0x6D) = op_CB_6D;
  *(optable_CB + 0x6E) = op_CB_6E;
  *(optable_CB + 0x6F) = op_CB_6F;

  *(optable_CB + 0x70) = op_CB_70;
  *(optable_CB + 0x71) = op_CB_71;
  *(optable_CB + 0x72) = op_CB_72;
  *(optable_CB + 0x73) = op_CB_73;
  *(optable_CB + 0x74) = op_CB_74;
  *(optable_CB + 0x75) = op_CB_75;
  *(optable_CB + 0x76) = op_CB_76;
  *(optable_CB + 0x77) = op_CB_77;
  *(optable_CB + 0x78) = op_CB_78;
  *(optable_CB + 0x79) = op_CB_79;
  *(optable_CB + 0x7A) = op_CB_7A;
  *(optable_CB + 0x7B) = op_CB_7B;
  *(optable_CB + 0x7C) = op_CB_7C;
  *(optable_CB + 0x7D) = op_CB_7D;
  *(optable_CB + 0x7E) = op_CB_7E;
  *(optable_CB + 0x7F) = op_CB_7F;

  *(optable_CB + 0x80) = op_CB_80;
  *(optable_CB + 0x81) = op_CB_81;
  *(optable_CB + 0x82) = op_CB_82;
  *(optable_CB + 0x83) = op_CB_83;
  *(optable_CB + 0x84) = op_CB_84;
  *(optable_CB + 0x85) = op_CB_85;
  *(optable_CB + 0x86) = op_CB_86;
  *(optable_CB + 0x87) = op_CB_87;
  *(optable_CB + 0x88) = op_CB_88;
  *(optable_CB + 0x89) = op_CB_89;
  *(optable_CB + 0x8A) = op_CB_8A;
  *(optable_CB + 0x8B) = op_CB_8B;
  *(optable_CB + 0x8C) = op_CB_8C;
  *(optable_CB + 0x8D) = op_CB_8D;
  *(optable_CB + 0x8E) = op_CB_8E;
  *(optable_CB + 0x8F) = op_CB_8F;

  *(optable_CB + 0x90) = op_CB_90;
  *(optable_CB + 0x91) = op_CB_91;
  *(optable_CB + 0x92) = op_CB_92;
  *(optable_CB + 0x93) = op_CB_93;
  *(optable_CB + 0x94) = op_CB_94;
  *(optable_CB + 0x95) = op_CB_95;
  *(optable_CB + 0x96) = op_CB_96;
  *(optable_CB + 0x97) = op_CB_97;
  *(optable_CB + 0x98) = op_CB_98;
  *(optable_CB + 0x99) = op_CB_99;
  *(optable_CB + 0x9A) = op_CB_9A;
  *(optable_CB + 0x9B) = op_CB_9B;
  *(optable_CB + 0x9C) = op_CB_9C;
  *(optable_CB + 0x9D) = op_CB_9D;
  *(optable_CB + 0x9E) = op_CB_9E;
  *(optable_CB + 0x9F) = op_CB_9F;

  *(optable_CB + 0xA0) = op_CB_A0;
  *(optable_CB + 0xA1) = op_CB_A1;
  *(optable_CB + 0xA2) = op_CB_A2;
  *(optable_CB + 0xA3) = op_CB_A3;
  *(optable_CB + 0xA4) = op_CB_A4;
  *(optable_CB + 0xA5) = op_CB_A5;
  *(optable_CB + 0xA6) = op_CB_A6;
  *(optable_CB + 0xA7) = op_CB_A7;
  *(optable_CB + 0xA8) = op_CB_A8;
  *(optable_CB + 0xA9) = op_CB_A9;
  *(optable_CB + 0xAA) = op_CB_AA;
  *(optable_CB + 0xAB) = op_CB_AB;
  *(optable_CB + 0xAC) = op_CB_AC;
  *(optable_CB + 0xAD) = op_CB_AD;
  *(optable_CB + 0xAE) = op_CB_AE;
  *(optable_CB + 0xAF) = op_CB_AF;

  *(optable_CB + 0xB0) = op_CB_B0;
  *(optable_CB + 0xB1) = op_CB_B1;
  *(optable_CB + 0xB2) = op_CB_B2;
  *(optable_CB + 0xB3) = op_CB_B3;
  *(optable_CB + 0xB4) = op_CB_B4;
  *(optable_CB + 0xB5) = op_CB_B5;
  *(optable_CB + 0xB6) = op_CB_B6;
  *(optable_CB + 0xB7) = op_CB_B7;
  *(optable_CB + 0xB8) = op_CB_B8;
  *(optable_CB + 0xB9) = op_CB_B9;
  *(optable_CB + 0xBA) = op_CB_BA;
  *(optable_CB + 0xBB) = op_CB_BB;
  *(optable_CB + 0xBC) = op_CB_BC;
  *(optable_CB + 0xBD) = op_CB_BD;
  *(optable_CB + 0xBE) = op_CB_BE;
  *(optable_CB + 0xBF) = op_CB_BF;

  *(optable_CB + 0xC0) = op_CB_C0;
  *(optable_CB + 0xC1) = op_CB_C1;
  *(optable_CB + 0xC2) = op_CB_C2;
  *(optable_CB + 0xC3) = op_CB_C3;
  *(optable_CB + 0xC4) = op_CB_C4;
  *(optable_CB + 0xC5) = op_CB_C5;
  *(optable_CB + 0xC6) = op_CB_C6;
  *(optable_CB + 0xC7) = op_CB_C7;
  *(optable_CB + 0xC8) = op_CB_C8;
  *(optable_CB + 0xC9) = op_CB_C9;
  *(optable_CB + 0xCA) = op_CB_CA;
  *(optable_CB + 0xCB) = op_CB_CB;
  *(optable_CB + 0xCC) = op_CB_CC;
  *(optable_CB + 0xCD) = op_CB_CD;
  *(optable_CB + 0xCE) = op_CB_CE;
  *(optable_CB + 0xCF) = op_CB_CF;

  *(optable_CB + 0xD0) = op_CB_D0;
  *(optable_CB + 0xD1) = op_CB_D1;
  *(optable_CB + 0xD2) = op_CB_D2;
  *(optable_CB + 0xD3) = op_CB_D3;
  *(optable_CB + 0xD4) = op_CB_D4;
  *(optable_CB + 0xD5) = op_CB_D5;
  *(optable_CB + 0xD6) = op_CB_D6;
  *(optable_CB + 0xD7) = op_CB_D7;
  *(optable_CB + 0xD8) = op_CB_D8;
  *(optable_CB + 0xD9) = op_CB_D9;
  *(optable_CB + 0xDA) = op_CB_DA;
  *(optable_CB + 0xDB) = op_CB_DB;
  *(optable_CB + 0xDC) = op_CB_DC;
  *(optable_CB + 0xDD) = op_CB_DD;
  *(optable_CB + 0xDE) = op_CB_DE;
  *(optable_CB + 0xDF) = op_CB_DF;

  *(optable_CB + 0xE0) = op_CB_E0;
  *(optable_CB + 0xE1) = op_CB_E1;
  *(optable_CB + 0xE2) = op_CB_E2;
  *(optable_CB + 0xE3) = op_CB_E3;
  *(optable_CB + 0xE4) = op_CB_E4;
  *(optable_CB + 0xE5) = op_CB_E5;
  *(optable_CB + 0xE6) = op_CB_E6;
  *(optable_CB + 0xE7) = op_CB_E7;
  *(optable_CB + 0xE8) = op_CB_E8;
  *(optable_CB + 0xE9) = op_CB_E9;
  *(optable_CB + 0xEA) = op_CB_EA;
  *(optable_CB + 0xEB) = op_CB_EB;
  *(optable_CB + 0xEC) = op_CB_EC;
  *(optable_CB + 0xED) = op_CB_ED;
  *(optable_CB + 0xEE) = op_CB_EE;
  *(optable_CB + 0xEF) = op_CB_EF;

  *(optable_CB + 0xF0) = op_CB_F0;
  *(optable_CB + 0xF1) = op_CB_F1;
  *(optable_CB + 0xF2) = op_CB_F2;
  *(optable_CB + 0xF3) = op_CB_F3;
  *(optable_CB + 0xF4) = op_CB_F4;
  *(optable_CB + 0xF5) = op_CB_F5;
  *(optable_CB + 0xF6) = op_CB_F6;
  *(optable_CB + 0xF7) = op_CB_F7;
  *(optable_CB + 0xF8) = op_CB_F8;
  *(optable_CB + 0xF9) = op_CB_F9;
  *(optable_CB + 0xFA) = op_CB_FA;
  *(optable_CB + 0xFB) = op_CB_FB;
  *(optable_CB + 0xFC) = op_CB_FC;
  *(optable_CB + 0xFD) = op_CB_FD;
  *(optable_CB + 0xFE) = op_CB_FE;
  *(optable_CB + 0xFF) = op_CB_FF;
}

def fini_optable() {
  free(optable as *uint8);
  free(optable_CB as *uint8);
}

// =============================================================================
// [CT] Cycle Table
// =============================================================================
let cycletable: *uint8;
let cycletable_CB: *uint8;

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

  *(cycletable + 0x70) = 8;
  *(cycletable + 0x71) = 8;
  *(cycletable + 0x72) = 8;
  *(cycletable + 0x73) = 8;
  *(cycletable + 0x74) = 8;
  *(cycletable + 0x75) = 8;
  *(cycletable + 0x76) = 4;
  *(cycletable + 0x77) = 8;
  *(cycletable + 0x78) = 4;
  *(cycletable + 0x79) = 4;
  *(cycletable + 0x7A) = 4;
  *(cycletable + 0x7B) = 4;
  *(cycletable + 0x7C) = 4;
  *(cycletable + 0x7D) = 4;
  *(cycletable + 0x7E) = 8;
  *(cycletable + 0x7F) = 4;

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
  // *(cycletable + 0xCB) = ~
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

  cycletable_CB = malloc(0x1_00) as *uint8;
  memset(cycletable_CB as *uint8, 0, 0x1_00);

  let idx = 0;
  while idx <= 0xF {
    *(cycletable_CB + (idx << 4) + 0x00) = 8;
    *(cycletable_CB + (idx << 4) + 0x01) = 8;
    *(cycletable_CB + (idx << 4) + 0x02) = 8;
    *(cycletable_CB + (idx << 4) + 0x03) = 8;
    *(cycletable_CB + (idx << 4) + 0x04) = 8;
    *(cycletable_CB + (idx << 4) + 0x05) = 8;
    *(cycletable_CB + (idx << 4) + 0x07) = 8;
    *(cycletable_CB + (idx << 4) + 0x08) = 8;
    *(cycletable_CB + (idx << 4) + 0x09) = 8;
    *(cycletable_CB + (idx << 4) + 0x0A) = 8;
    *(cycletable_CB + (idx << 4) + 0x0B) = 8;
    *(cycletable_CB + (idx << 4) + 0x0C) = 8;
    *(cycletable_CB + (idx << 4) + 0x0D) = 8;
    *(cycletable_CB + (idx << 4) + 0x0F) = 8;

    if idx >= 4 and idx <= 7 {
      *(cycletable_CB + (idx << 4) + 0x06) = 12;
      *(cycletable_CB + (idx << 4) + 0x0E) = 12;
    } else {
      *(cycletable_CB + (idx << 4) + 0x06) = 16;
      *(cycletable_CB + (idx << 4) + 0x0E) = 16;
    }

    idx += 1;
  }
}

def fini_cycletable() {
  free(cycletable as *uint8);
  free(cycletable_CB as *uint8);
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
def om_inc8(r: uint8): uint8 {
  r += 1;

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, r & 0x0F == 0x00);

  return r;
}

// Decrement 8-bit Register
def om_dec8(r: uint8): uint8 {
  r -= 1;

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, true);
  flag_set(FLAG_H, r & 0x0F == 0x0F);

  return r;
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
  let r = a | b;

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
  let r = uint16(a) + uint16(b);

  flag_set(FLAG_H, ((a & 0x0F) + (b & 0x0F)) > 0x0F);
  flag_set(FLAG_Z, (r & 0xFF) == 0);
  flag_set(FLAG_C, r > 0xFF);
  flag_set(FLAG_N, false);

  return uint8(r & 0xFF);
}

// Add 8-bit value w/carry
def om_adc8(a: uint8, b: uint8): uint8 {
  let carry = uint16(flag_geti(FLAG_C));
  let r = uint16(a) + uint16(b) + carry;

  flag_set(FLAG_H, ((a & 0x0F) + (b & 0x0F) + uint8(carry)) > 0x0F);
  flag_set(FLAG_Z, (r & 0xFF) == 0);
  flag_set(FLAG_C, r > 0xFF);
  flag_set(FLAG_N, false);

  return uint8(r & 0xFF);
}

// Subtract 8-bit value
def om_sub8(a: uint8, b: uint8): uint8 {
  let r = int16(a) - int16(b);

  flag_set(FLAG_C, r < 0);
  flag_set(FLAG_Z, (r & 0xFF) == 0);
  flag_set(FLAG_N, true);
  flag_set(FLAG_H, (((int16(a) & 0x0F) - (int16(b) & 0x0F)) < 0));

  return uint8(r & 0xFF);
}

// Subtract 8-bit value w/carry
def om_sbc8(a: uint8, b: uint8): uint8 {
  let carry = int16(flag_geti(FLAG_C));
  let r = int16(a) - int16(b) - carry;

  flag_set(FLAG_C, r < 0);
  flag_set(FLAG_Z, (r & 0xFF) == 0);
  flag_set(FLAG_N, true);
  flag_set(FLAG_H, (((int16(a) & 0x0F) - (int16(b) & 0x0F) - carry) < 0));

  return uint8(r & 0xFF);
}

// Add 16-bit value
def om_add16(a: uint16, b: uint16): uint16 {
  let r = uint32(a) + uint32(b);

  flag_set(FLAG_H, ((a ^ b ^ uint16(r & 0xFFFF)) & 0x1000) != 0);
  flag_set(FLAG_C, r > 0xFFFF);
  flag_set(FLAG_N, false);

  return uint16(r & 0xFFFF);
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

// Relative Jump
// 7-bit relative jump address with a sign bit to indicate +/-
def om_jr(n: uint8) {
  om_jp(uint16(int16(PC) + int16(int8(n))));
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

// Byte Swap
def om_swap8(n: uint8): uint8 {
  let r = (n >> 4) | ((n << 4) & 0xF0);

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, false);
  flag_set(FLAG_C, false);

  return r;
}

// Shift Right
def om_shr(n: uint8, arithmetic: bool): uint8 {
  let r = if arithmetic {
    if (n & 0x80) != 0 {
      (n >> 1) | 0x80;
    } else {
      (n >> 1);
    }
  } else {
    (n >> 1);
  };

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, false);
  flag_set(FLAG_C, (n & 0x01) != 0);

  return r;
}

// Shift Left
def om_shl(n: uint8): uint8 {
  let r = (n << 1);

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, false);
  flag_set(FLAG_C, (n & 0x80) != 0);

  return r;
}

// Rotate Left (opt. through carry)
def om_rotl8(n: uint8, carry: bool): uint8 {
  let r = if carry {
    (n << 1) | flag_geti(FLAG_C);
  } else {
    (n << 1) | (n >> 7);
  };

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, false);
  flag_set(FLAG_C, ((n & 0x80) != 0));

  return r;
}

// Rotate Right (opt. through carry)
def om_rotr8(n: uint8, carry: bool): uint8 {
  let r = if carry {
    (n >> 1) | (flag_geti(FLAG_C) << 7);
  } else {
    (n >> 1) | (n << 7);
  };

  flag_set(FLAG_Z, r == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, false);
  flag_set(FLAG_C, ((n & 0x01) != 0));

  return r;
}

// Bit Test
def om_bit8(n: uint8, b: uint8) {
  flag_set(FLAG_Z, (n & (1 << b)) == 0);
  flag_set(FLAG_N, false);
  flag_set(FLAG_H, true);
}

// Bit Set
def om_set8(n: uint8, b: uint8): uint8 {
  return n | (1 << b);
}

// Bit Reset
def om_res8(n: uint8, b: uint8): uint8 {
  return n & ~(1 << b);
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
  *B = om_inc8(*B);
}

// [05] DEC B
def op_05() {
  *B = om_dec8(*B);
}

// [06] LD B, n
def op_06() {
  *B = mmu_next8();
}

// [07] RLCA
def op_07() {
  *A = om_rotl8(*A, false);
  flag_set(FLAG_Z, false);
}

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
  *C = om_inc8(*C);
}

// [0D] DEC C
def op_0D() {
  *C = om_dec8(*C);
}

// [0E] LD C, n
def op_0E() {
  *C = mmu_next8();
}

// [0F] RRCA
def op_0F() {
  *A = om_rotr8(*A, false);
  flag_set(FLAG_Z, false);
}

// [10] STOP
def op_10() {
  cpu_stop = true;
}

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
  *D = om_inc8(*D);
}

// [15] DEC D
def op_15() {
  *D = om_dec8(*D);
}

// [16] LD D, n
def op_16() {
  *D = mmu_next8();
}

// [17] RLA
def op_17() {
  *A = om_rotl8(*A, true);
  flag_set(FLAG_Z, false);
}

// [18] JR n
def op_18() {
  om_jr(mmu_next8());
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
  *E = om_inc8(*E);
}

// [1D] DEC E
def op_1D() {
  *E = om_dec8(*E);
}

// [1E] LD E, n
def op_1E() {
  *E = mmu_next8();
}

// [1F] RRA
def op_1F() {
  *A = om_rotr8(*A, true);
  flag_set(FLAG_Z, false);
}

// [20] JR NZ, n
def op_20() {
  let n = mmu_next8();
  if not flag_get(FLAG_Z) {
    om_jr(n);
    CYCLES += 4;
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
  *H = om_inc8(*H);
}

// [25] DEC H
def op_25() {
  *H = om_dec8(*H);
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
  let correction: uint16 = if flag_get(FLAG_C) { 0x60; } else { 0x00; };

  if flag_get(FLAG_H) or ((not flag_get(FLAG_N)) and ((r & 0x0F) > 9)) {
    correction |= 0x06;
  }

  if flag_get(FLAG_C) or ((not flag_get(FLAG_N)) and (r > 0x99)) {
    correction |= 0x60;
  }

  if flag_get(FLAG_N) {
    r -= correction;
  } else {
    r += correction;
  }

  if ((correction << 2) & 0x100) != 0 {
    flag_set(FLAG_C, true);
  }

  // NOTE: Half-carry is always unset (unlike a Z-80)
  flag_set(FLAG_H, false);

  *A = uint8(r & 0xFF);

  flag_set(FLAG_Z, *A == 0);
}

// [28] JR Z, n
def op_28() {
  let n = mmu_next8();
  if flag_get(FLAG_Z) {
    om_jr(n);
    CYCLES += 4;
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
  *L = om_inc8(*L);
}

// [2D] DEC L
def op_2D() {
  *L = om_dec8(*L);
}

// [2E] LD L, n
def op_2E() {
  *L = mmu_next8();
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
    om_jr(n);
    CYCLES += 4;
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
  mmu_write8(HL, om_inc8(mmu_read8(HL)));
}

// [35] DEC (HL)
def op_35() {
  mmu_write8(HL, om_dec8(mmu_read8(HL)));
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
    om_jr(n);
    CYCLES += 4;
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
  *A = om_inc8(*A);
}

// [3D] DEC A
def op_3D() {
  *A = om_dec8(*A);
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

// [70] LD (HL), B
def op_70() {
  mmu_write8(HL, *B);
}

// [71] LD (HL), C
def op_71() {
  mmu_write8(HL, *C);
}

// [72] LD (HL), D
def op_72() {
  mmu_write8(HL, *D);
}

// [73] LD (HL), E
def op_73() {
  mmu_write8(HL, *E);
}

// [74] LD (HL), H
def op_74() {
  mmu_write8(HL, *H);
}

// [75] LD (HL), L
def op_75() {
  mmu_write8(HL, *L);
}

// [76] HALT
def op_76() {
  if (not IME) and (IE & IF & 0x1F) != 0 {
    cpu_skip = true;
  } else {
    HALT = true;
  }
}

// [77] LD (HL), A
def op_77() {
  mmu_write8(HL, *A);
}

// [78] LD A, B
def op_78() {
  *A = *B;
}

// [79] LD A, C
def op_79() {
  *A = *C;
}

// [7A] LD A, D
def op_7A() {
  *A = *D;
}

// [7B] LD A, E
def op_7B() {
  *A = *E;
}

// [7C] LD A, H
def op_7C() {
  *A = *H;
}

// [7D] LD A, L
def op_7D() {
  *A = *L;
}

// [7E] LD A, (HL)
def op_7E() {
  *A = mmu_read8(HL);
}

// [7F] LD A, A
def op_7F() {
  *A = *A;
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
  *A = om_add8(*A, *D);
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
  *A = om_adc8(*A, *D);
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
  *A = om_sub8(*A, *D);
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
  *A = om_sbc8(*A, *D);
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
  *A = om_and8(*A, *D);
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
  *A = om_xor8(*A, *D);
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
  *A = om_or8(*A, *D);
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
  om_sub8(*A, *D);
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
    CYCLES += 12;
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
    CYCLES += 4;
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
    CYCLES += 12;
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
  om_call(0x00);
}

// [C8] RET Z
def op_C8() {
  if flag_get(FLAG_Z) {
    om_ret();
    CYCLES += 12;
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
    CYCLES += 4;
  }
}

// [CB] ~
def op_CB() {
  // Get next opcode
  let opcode = mmu_next8();

  // Check if valid/known instruction
  if *((optable_CB as *int64) + opcode) == 0 {
    printf("error: unknown opcode: $CB $%02X\n", opcode);
    exit(-1);
  }

  // Set instruction time to the base/min
  CYCLES += *(cycletable_CB + opcode);

  // DEBUG: TRACE
  // printf("PC: $%04X AF: $%04X BC: $%04X DE: $%04X HL: $%04X SP: $%04X\n",
  //   PC - 1,
  //   AF,
  //   BC,
  //   DE,
  //   HL,
  //   SP,
  // );

  // Execute instruction
  (*(optable_CB + opcode))();
}

// [CC] CALL Z, nn
def op_CC() {
  let nn = mmu_next16();
  if flag_get(FLAG_Z) {
    om_call(nn);
    CYCLES += 12;
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
  om_call(0x08);
}

// [D0] RET NC
def op_D0() {
  if not flag_get(FLAG_C) {
    om_ret();
    CYCLES += 12;
  }
}

// [D1] POP DE
def op_D1() {
  om_pop16(&DE);
}

// [D2] JP NC, u16
def op_D2() {
  let address = mmu_next16();
  if not flag_get(FLAG_C) {
    om_jp(address);
    CYCLES += 4;
  }
}

// [D4] CALL NC, u16
def op_D4() {
  let address = mmu_next16();
  if not flag_get(FLAG_C) {
    om_call(address);
    CYCLES += 12;
  }
}

// [D5] PUSH DE
def op_D5() {
  om_push16(&DE);
}

// [D6] SUB A, u8
def op_D6() {
  *A = om_sub8(*A, mmu_next8());
}

// [D7] RST $10
def op_D7() {
  om_call(0x10);
}

// [D8] RET C
def op_D8() {
  if flag_get(FLAG_C) {
    om_ret();
    CYCLES += 12;
  }
}

// [D9] RETI
def op_D9() {
  om_ret();
  IME = true;
}

// [DA] JP C, u16
def op_DA() {
  let address = mmu_next16();
  if flag_get(FLAG_C) {
    om_jp(address);
    CYCLES += 4;
  }
}

// [DC] CALL C, u16
def op_DC() {
  let address = mmu_next16();
  if flag_get(FLAG_C) {
    om_call(address);
    CYCLES += 12;
  }
}

// [DE] SBC A, u8
def op_DE() {
  *A = om_sbc8(*A, mmu_next8());
}

// [DF] RST $18
def op_DF() {
  om_call(0x18);
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
  om_call(0x20);
}

// [E8] ADD SP, i8
def op_E8() {
  let n = int16(int8(mmu_next8()));
  let r = uint16(int16(SP) + n);

  flag_set(FLAG_C, (r & 0xFF) < (SP & 0xFF));
  flag_set(FLAG_H, (r & 0xF) < (SP & 0xF));
  flag_set(FLAG_Z, false);
  flag_set(FLAG_N, false);

  SP = r;
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
  om_call(0x28);
}

// [F0] LD A, ($FF00 + n)
def op_F0() {
  let n = mmu_next8();
  // printf("\tLD A, ($FF00 + $%02X)\n", n);
  *A = mmu_read8(0xFF00 + uint16(n));
  // printf("\t\t -> %02X\n", *A);
}

// [F1] POP AF
def op_F1() {
  om_pop16(&AF);

  // NOTE: The F register can only ever have the top 4 bits set
  *F &= 0xF0;
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
  om_call(0x30);
}

// [F8] LD HL, SP + i8
def op_F8() {
  let n = int16(int8(mmu_next8()));
  let r = uint16(int16(SP) + n);

  flag_set(FLAG_C, (r & 0xFF) < (SP & 0xFF));
  flag_set(FLAG_H, (r & 0xF) < (SP & 0xF));
  flag_set(FLAG_Z, false);
  flag_set(FLAG_N, false);

  HL = r;
}

// [F9] LD SP, HL
def op_F9() {
  SP = HL;
}

// [FA] LD A, (nn)
def op_FA() {
  *A = mmu_read8(mmu_next16());
}

// [FB] EI
def op_FB() {
  IME_pending = true;
}

// [FE] CP n
def op_FE()
{
  let n = mmu_next8();
  om_sub8(*A, n);
}

// [FF] RST $38
def op_FF() {
  om_call(0x38);
}

// [CB 00] RLC B
def op_CB_00() {
  *B = om_rotl8(*B, false);
}

// [CB 01] RLC C
def op_CB_01() {
  *C = om_rotl8(*C, false);
}

// [CB 02] RLC D
def op_CB_02() {
  *D = om_rotl8(*D, false);
}

// [CB 03] RLC E
def op_CB_03() {
  *E = om_rotl8(*E, false);
}

// [CB 04] RLC H
def op_CB_04() {
  *H = om_rotl8(*H, false);
}

// [CB 05] RLC L
def op_CB_05() {
  *L = om_rotl8(*L, false);
}

// [CB 06] RLC (HL)
def op_CB_06() {
  mmu_write8(HL, om_rotl8(mmu_read8(HL), false));
}

// [CB 07] RLC A
def op_CB_07() {
  *A = om_rotl8(*A, false);
}

// [CB 08] RRC B
def op_CB_08() {
  *B = om_rotr8(*B, false);
}

// [CB 09] RRC C
def op_CB_09() {
  *C = om_rotr8(*C, false);
}

// [CB 0A] RRC D
def op_CB_0A() {
  *D = om_rotr8(*D, false);
}

// [CB 0B] RRC E
def op_CB_0B() {
  *E = om_rotr8(*E, false);
}

// [CB 0C] RRC H
def op_CB_0C() {
  *H = om_rotr8(*H, false);
}

// [CB 0D] RRC L
def op_CB_0D() {
  *L = om_rotr8(*L, false);
}

// [CB 0E] RRC (HL)
def op_CB_0E() {
  mmu_write8(HL, om_rotr8(mmu_read8(HL), false));
}

// [CB 0F] RRC A
def op_CB_0F() {
  *A = om_rotr8(*A, false);
}

// [CB 10] RL B
def op_CB_10() {
  *B = om_rotl8(*B, true);
}

// [CB 11] RL C
def op_CB_11() {
  *C = om_rotl8(*C, true);
}

// [CB 12] RL D
def op_CB_12() {
  *D = om_rotl8(*D, true);
}

// [CB 13] RL E
def op_CB_13() {
  *E = om_rotl8(*E, true);
}

// [CB 14] RL H
def op_CB_14() {
  *H = om_rotl8(*H, true);
}

// [CB 15] RL L
def op_CB_15() {
  *L = om_rotl8(*L, true);
}

// [CB 16] RL (HL)
def op_CB_16() {
  mmu_write8(HL, om_rotl8(mmu_read8(HL), true));
}

// [CB 17] RL A
def op_CB_17() {
  *A = om_rotl8(*A, true);
}

// [CB 18] RR B
def op_CB_18() {
  *B = om_rotr8(*B, true);
}

// [CB 19] RR C
def op_CB_19() {
  *C = om_rotr8(*C, true);
}

// [CB 1A] RR D
def op_CB_1A() {
  *D = om_rotr8(*D, true);
}

// [CB 1B] RR E
def op_CB_1B() {
  *E = om_rotr8(*E, true);
}

// [CB 1C] RR H
def op_CB_1C() {
  *H = om_rotr8(*H, true);
}

// [CB 1D] RR L
def op_CB_1D() {
  *L = om_rotr8(*L, true);
}

// [CB 1E] RR (HL)
def op_CB_1E() {
  mmu_write8(HL, om_rotr8(mmu_read8(HL), true));
}

// [CB 1F] RR A
def op_CB_1F() {
  *A = om_rotr8(*A, true);
}

// [CB 20] SLA B
def op_CB_20() {
  *B = om_shl(*B);
}

// [CB 21] SLA C
def op_CB_21() {
  *C = om_shl(*C);
}

// [CB 22] SLA D
def op_CB_22() {
  *D = om_shl(*D);
}

// [CB 23] SLA E
def op_CB_23() {
  *E = om_shl(*E);
}

// [CB 24] SLA H
def op_CB_24() {
  *H = om_shl(*H);
}

// [CB 25] SLA L
def op_CB_25() {
  *L = om_shl(*L);
}

// [CB 26] SLA (HL)
def op_CB_26() {
  mmu_write8(HL, om_shl(mmu_read8(HL)));
}

// [CB 27] SLA A
def op_CB_27() {
  *A = om_shl(*A);
}

// [CB 28] SRA B
def op_CB_28() {
  *B = om_shr(*B, true);
}

// [CB 29] SRA C
def op_CB_29() {
  *C = om_shr(*C, true);
}

// [CB 2A] SRA D
def op_CB_2A() {
  *D = om_shr(*D, true);
}

// [CB 2B] SRA E
def op_CB_2B() {
  *E = om_shr(*E, true);
}

// [CB 2C] SRA H
def op_CB_2C() {
  *H = om_shr(*H, true);
}

// [CB 2D] SRA L
def op_CB_2D() {
  *L = om_shr(*L, true);
}

// [CB 2E] SRA (HL)
def op_CB_2E() {
  mmu_write8(HL, om_shr(mmu_read8(HL), true));
}

// [CB 2F] SRA A
def op_CB_2F() {
  *A = om_shr(*A, true);
}

// [CB 30] SWAP B
def op_CB_30() {
  *B = om_swap8(*B);
}

// [CB 31] SWAP C
def op_CB_31() {
  *C = om_swap8(*C);
}

// [CB 32] SWAP D
def op_CB_32() {
  *D = om_swap8(*D);
}

// [CB 33] SWAP E
def op_CB_33() {
  *E = om_swap8(*E);
}

// [CB 34] SWAP H
def op_CB_34() {
  *H = om_swap8(*H);
}

// [CB 35] SWAP L
def op_CB_35() {
  *L = om_swap8(*L);
}

// [CB 36] SWAP (HL)
def op_CB_36() {
  mmu_write8(HL, om_swap8(mmu_read8(HL)));
}

// [CB 37] SWAP A
def op_CB_37() {
  *A = om_swap8(*A);
}

// [CB 38] SRL B
def op_CB_38() {
  *B = om_shr(*B, false);
}

// [CB 39] SRL C
def op_CB_39() {
  *C = om_shr(*C, false);
}

// [CB 3A] SRL D
def op_CB_3A() {
  *D = om_shr(*D, false);
}

// [CB 3B] SRL E
def op_CB_3B() {
  *E = om_shr(*E, false);
}

// [CB 3C] SRL H
def op_CB_3C() {
  *H = om_shr(*H, false);
}

// [CB 3D] SRL L
def op_CB_3D() {
  *L = om_shr(*L, false);
}

// [CB 3E] SRL (HL)
def op_CB_3E() {
  mmu_write8(HL, om_shr(mmu_read8(HL), false));
}

// [CB 3F] SRL A
def op_CB_3F() {
  *A = om_shr(*A, false);
}

// [CB 40] BIT 0, B
def op_CB_40() {
  om_bit8(*B, 0);
}

// [CB 41] BIT 0, C
def op_CB_41() {
  om_bit8(*C, 0);
}

// [CB 42] BIT 0, D
def op_CB_42() {
  om_bit8(*D, 0);
}

// [CB 43] BIT 0, E
def op_CB_43() {
  om_bit8(*E, 0);
}

// [CB 44] BIT 0, H
def op_CB_44() {
  om_bit8(*H, 0);
}

// [CB 45] BIT 0, L
def op_CB_45() {
  om_bit8(*L, 0);
}

// [CB 46] BIT 0, (HL)
def op_CB_46() {
  om_bit8(mmu_read8(HL), 0);
}

// [CB 47] BIT 0, A
def op_CB_47() {
  om_bit8(*A, 0);
}

// [CB 48] BIT 1, B
def op_CB_48() {
  om_bit8(*B, 1);
}

// [CB 49] BIT 1, C
def op_CB_49() {
  om_bit8(*C, 1);
}

// [CB 4A] BIT 1, D
def op_CB_4A() {
  om_bit8(*D, 1);
}

// [CB 4B] BIT 1, E
def op_CB_4B() {
  om_bit8(*E, 1);
}

// [CB 4C] BIT 1, H
def op_CB_4C() {
  om_bit8(*H, 1);
}

// [CB 4D] BIT 1, L
def op_CB_4D() {
  om_bit8(*L, 1);
}

// [CB 4E] BIT 1, (HL)
def op_CB_4E() {
  om_bit8(mmu_read8(HL), 1);
}

// [CB 4F] BIT 1, A
def op_CB_4F() {
  om_bit8(*A, 1);
}

// [CB 50] BIT 2, B
def op_CB_50() {
  om_bit8(*B, 2);
}

// [CB 51] BIT 2, C
def op_CB_51() {
  om_bit8(*C, 2);
}

// [CB 52] BIT 2, D
def op_CB_52() {
  om_bit8(*D, 2);
}

// [CB 53] BIT 2, E
def op_CB_53() {
  om_bit8(*E, 2);
}

// [CB 54] BIT 2, H
def op_CB_54() {
  om_bit8(*H, 2);
}

// [CB 55] BIT 2, L
def op_CB_55() {
  om_bit8(*L, 2);
}

// [CB 56] BIT 2, (HL)
def op_CB_56() {
  om_bit8(mmu_read8(HL), 2);
}

// [CB 57] BIT 2, A
def op_CB_57() {
  om_bit8(*A, 2);
}

// [CB 58] BIT 3, B
def op_CB_58() {
  om_bit8(*B, 3);
}

// [CB 59] BIT 3, C
def op_CB_59() {
  om_bit8(*C, 3);
}

// [CB 5A] BIT 3, D
def op_CB_5A() {
  om_bit8(*D, 3);
}

// [CB 5B] BIT 3, E
def op_CB_5B() {
  om_bit8(*E, 3);
}

// [CB 5C] BIT 3, H
def op_CB_5C() {
  om_bit8(*H, 3);
}

// [CB 5D] BIT 3, L
def op_CB_5D() {
  om_bit8(*L, 3);
}

// [CB 5E] BIT 3, (HL)
def op_CB_5E() {
  om_bit8(mmu_read8(HL), 3);
}

// [CB 5F] BIT 3, A
def op_CB_5F() {
  om_bit8(*A, 3);
}

// [CB 60] BIT 4, B
def op_CB_60() {
  om_bit8(*B, 4);
}

// [CB 61] BIT 4, C
def op_CB_61() {
  om_bit8(*C, 4);
}

// [CB 62] BIT 4, D
def op_CB_62() {
  om_bit8(*D, 4);
}

// [CB 63] BIT 4, E
def op_CB_63() {
  om_bit8(*E, 4);
}

// [CB 64] BIT 4, H
def op_CB_64() {
  om_bit8(*H, 4);
}

// [CB 65] BIT 4, L
def op_CB_65() {
  om_bit8(*L, 4);
}

// [CB 66] BIT 4, (HL)
def op_CB_66() {
  om_bit8(mmu_read8(HL), 4);
}

// [CB 67] BIT 4, A
def op_CB_67() {
  om_bit8(*A, 4);
}

// [CB 68] BIT 5, B
def op_CB_68() {
  om_bit8(*B, 5);
}

// [CB 69] BIT 5, C
def op_CB_69() {
  om_bit8(*C, 5);
}

// [CB 6A] BIT 5, D
def op_CB_6A() {
  om_bit8(*D, 5);
}

// [CB 6B] BIT 5, E
def op_CB_6B() {
  om_bit8(*E, 5);
}

// [CB 6C] BIT 5, H
def op_CB_6C() {
  om_bit8(*H, 5);
}

// [CB 6D] BIT 5, L
def op_CB_6D() {
  om_bit8(*L, 5);
}

// [CB 6E] BIT 5, (HL)
def op_CB_6E() {
  om_bit8(mmu_read8(HL), 5);
}

// [CB 6F] BIT 5, A
def op_CB_6F() {
  om_bit8(*A, 5);
}

// [CB 70] BIT 6, B
def op_CB_70() {
  om_bit8(*B, 6);
}

// [CB 71] BIT 6, C
def op_CB_71() {
  om_bit8(*C, 6);
}

// [CB 72] BIT 6, D
def op_CB_72() {
  om_bit8(*D, 6);
}

// [CB 73] BIT 6, E
def op_CB_73() {
  om_bit8(*E, 6);
}

// [CB 74] BIT 6, H
def op_CB_74() {
  om_bit8(*H, 6);
}

// [CB 75] BIT 6, L
def op_CB_75() {
  om_bit8(*L, 6);
}

// [CB 76] BIT 6, (HL)
def op_CB_76() {
  om_bit8(mmu_read8(HL), 6);
}

// [CB 77] BIT 6, A
def op_CB_77() {
  om_bit8(*A, 6);
}

// [CB 78] BIT 7, B
def op_CB_78() {
  om_bit8(*B, 7);
}

// [CB 79] BIT 7, C
def op_CB_79() {
  om_bit8(*C, 7);
}

// [CB 7A] BIT 7, D
def op_CB_7A() {
  om_bit8(*D, 7);
}

// [CB 7B] BIT 7, E
def op_CB_7B() {
  om_bit8(*E, 7);
}

// [CB 7C] BIT 7, H
def op_CB_7C() {
  om_bit8(*H, 7);
}

// [CB 7D] BIT 7, L
def op_CB_7D() {
  om_bit8(*L, 7);
}

// [CB 7E] BIT 7, (HL)
def op_CB_7E() {
  om_bit8(mmu_read8(HL), 7);
}

// [CB 7F] BIT 7, A
def op_CB_7F() {
  om_bit8(*A, 7);
}

// [CB 80] RES 0, B
def op_CB_80() {
  *B = om_res8(*B, 0);
}

// [CB 81] RES 0, C
def op_CB_81() {
  *C = om_res8(*C, 0);
}

// [CB 82] RES 0, D
def op_CB_82() {
  *D = om_res8(*D, 0);
}

// [CB 83] RES 0, E
def op_CB_83() {
  *E = om_res8(*E, 0);
}

// [CB 84] RES 0, H
def op_CB_84() {
  *H = om_res8(*H, 0);
}

// [CB 85] RES 0, L
def op_CB_85() {
  *L = om_res8(*L, 0);
}

// [CB 86] RES 0, (HL)
def op_CB_86() {
  mmu_write8(HL, om_res8(mmu_read8(HL), 0));
}

// [CB 87] RES 0, A
def op_CB_87() {
  *A = om_res8(*A, 0);
}

// [CB 88] RES 1, B
def op_CB_88() {
  *B = om_res8(*B, 1);
}

// [CB 89] RES 1, C
def op_CB_89() {
  *C = om_res8(*C, 1);
}

// [CB 8A] RES 1, D
def op_CB_8A() {
  *D = om_res8(*D, 1);
}

// [CB 8B] RES 1, E
def op_CB_8B() {
  *E = om_res8(*E, 1);
}

// [CB 8C] RES 1, H
def op_CB_8C() {
  *H = om_res8(*H, 1);
}

// [CB 8D] RES 1, L
def op_CB_8D() {
  *L = om_res8(*L, 1);
}

// [CB 8E] RES 1, (HL)
def op_CB_8E() {
  mmu_write8(HL, om_res8(mmu_read8(HL), 1));
}

// [CB 8F] RES 1, A
def op_CB_8F() {
  *A = om_res8(*A, 1);
}

// [CB 90] RES 2, B
def op_CB_90() {
  *B = om_res8(*B, 2);
}

// [CB 91] RES 2, C
def op_CB_91() {
  *C = om_res8(*C, 2);
}

// [CB 92] RES 2, D
def op_CB_92() {
  *D = om_res8(*D, 2);
}

// [CB 93] RES 2, E
def op_CB_93() {
  *E = om_res8(*E, 2);
}

// [CB 94] RES 2, H
def op_CB_94() {
  *H = om_res8(*H, 2);
}

// [CB 95] RES 2, L
def op_CB_95() {
  *L = om_res8(*L, 2);
}

// [CB 96] RES 2, (HL)
def op_CB_96() {
  mmu_write8(HL, om_res8(mmu_read8(HL), 2));
}

// [CB 97] RES 2, A
def op_CB_97() {
  *A = om_res8(*A, 2);
}

// [CB 98] RES 3, B
def op_CB_98() {
  *B = om_res8(*B, 3);
}

// [CB 99] RES 3, C
def op_CB_99() {
  *C = om_res8(*C, 3);
}

// [CB 9A] RES 3, D
def op_CB_9A() {
  *D = om_res8(*D, 3);
}

// [CB 9B] RES 3, E
def op_CB_9B() {
  *E = om_res8(*E, 3);
}

// [CB 9C] RES 3, H
def op_CB_9C() {
  *H = om_res8(*H, 3);
}

// [CB 9D] RES 3, L
def op_CB_9D() {
  *L = om_res8(*L, 3);
}

// [CB 9E] RES 3, (HL)
def op_CB_9E() {
  mmu_write8(HL, om_res8(mmu_read8(HL), 3));
}

// [CB 9F] RES 3, A
def op_CB_9F() {
  *A = om_res8(*A, 3);
}

// [CB A0] RES 4, B
def op_CB_A0() {
  *B = om_res8(*B, 4);
}

// [CB A1] RES 4, C
def op_CB_A1() {
  *C = om_res8(*C, 4);
}

// [CB A2] RES 4, D
def op_CB_A2() {
  *D = om_res8(*D, 4);
}

// [CB A3] RES 4, E
def op_CB_A3() {
  *E = om_res8(*E, 4);
}

// [CB A4] RES 4, H
def op_CB_A4() {
  *H = om_res8(*H, 4);
}

// [CB A5] RES 4, L
def op_CB_A5() {
  *L = om_res8(*L, 4);
}

// [CB A6] RES 4, (HL)
def op_CB_A6() {
  mmu_write8(HL, om_res8(mmu_read8(HL), 4));
}

// [CB A7] RES 4, A
def op_CB_A7() {
  *A = om_res8(*A, 4);
}

// [CB A8] RES 5, B
def op_CB_A8() {
  *B = om_res8(*B, 5);
}

// [CB A9] RES 5, C
def op_CB_A9() {
  *C = om_res8(*C, 5);
}

// [CB AA] RES 5, D
def op_CB_AA() {
  *D = om_res8(*D, 5);
}

// [CB AB] RES 5, E
def op_CB_AB() {
  *E = om_res8(*E, 5);
}

// [CB AC] RES 5, H
def op_CB_AC() {
  *H = om_res8(*H, 5);
}

// [CB AD] RES 5, L
def op_CB_AD() {
  *L = om_res8(*L, 5);
}

// [CB AE] RES 5, (HL)
def op_CB_AE() {
  mmu_write8(HL, om_res8(mmu_read8(HL), 5));
}

// [CB AF] RES 5, A
def op_CB_AF() {
  *A = om_res8(*A, 5);
}

// [CB B0] RES 6, B
def op_CB_B0() {
  *B = om_res8(*B, 6);
}

// [CB B1] RES 6, C
def op_CB_B1() {
  *C = om_res8(*C, 6);
}

// [CB B2] RES 6, D
def op_CB_B2() {
  *D = om_res8(*D, 6);
}

// [CB B3] RES 6, E
def op_CB_B3() {
  *E = om_res8(*E, 6);
}

// [CB B4] RES 6, H
def op_CB_B4() {
  *H = om_res8(*H, 6);
}

// [CB B5] RES 6, L
def op_CB_B5() {
  *L = om_res8(*L, 6);
}

// [CB B6] RES 6, (HL)
def op_CB_B6() {
  mmu_write8(HL, om_res8(mmu_read8(HL), 6));
}

// [CB B7] RES 6, A
def op_CB_B7() {
  *A = om_res8(*A, 6);
}

// [CB B8] RES 7, B
def op_CB_B8() {
  *B = om_res8(*B, 7);
}

// [CB B9] RES 7, C
def op_CB_B9() {
  *C = om_res8(*C, 7);
}

// [CB BA] RES 7, D
def op_CB_BA() {
  *D = om_res8(*D, 7);
}

// [CB BB] RES 7, E
def op_CB_BB() {
  *E = om_res8(*E, 7);
}

// [CB BC] RES 7, H
def op_CB_BC() {
  *H = om_res8(*H, 7);
}

// [CB BD] RES 7, L
def op_CB_BD() {
  *L = om_res8(*L, 7);
}

// [CB BE] RES 7, (HL)
def op_CB_BE() {
  mmu_write8(HL, om_res8(mmu_read8(HL), 7));
}

// [CB BF] RES 7, A
def op_CB_BF() {
  *A = om_res8(*A, 7);
}

// [CB C0] SET 0, B
def op_CB_C0() {
  *B = om_set8(*B, 0);
}

// [CB C1] SET 0, C
def op_CB_C1() {
  *C = om_set8(*C, 0);
}

// [CB C2] SET 0, D
def op_CB_C2() {
  *D = om_set8(*D, 0);
}

// [CB C3] SET 0, E
def op_CB_C3() {
  *E = om_set8(*E, 0);
}

// [CB C4] SET 0, H
def op_CB_C4() {
  *H = om_set8(*H, 0);
}

// [CB C5] SET 0, L
def op_CB_C5() {
  *L = om_set8(*L, 0);
}

// [CB C6] SET 0, (HL)
def op_CB_C6() {
  mmu_write8(HL, om_set8(mmu_read8(HL), 0));
}

// [CB C7] SET 0, A
def op_CB_C7() {
  *A = om_set8(*A, 0);
}

// [CB C8] SET 1, B
def op_CB_C8() {
  *B = om_set8(*B, 1);
}

// [CB C9] SET 1, C
def op_CB_C9() {
  *C = om_set8(*C, 1);
}

// [CB CA] SET 1, D
def op_CB_CA() {
  *D = om_set8(*D, 1);
}

// [CB CB] SET 1, E
def op_CB_CB() {
  *E = om_set8(*E, 1);
}

// [CB CC] SET 1, H
def op_CB_CC() {
  *H = om_set8(*H, 1);
}

// [CB CD] SET 1, L
def op_CB_CD() {
  *L = om_set8(*L, 1);
}

// [CB CE] SET 1, (HL)
def op_CB_CE() {
  mmu_write8(HL, om_set8(mmu_read8(HL), 1));
}

// [CB CF] SET 1, A
def op_CB_CF() {
  *A = om_set8(*A, 1);
}

// [CB D0] SET 2, B
def op_CB_D0() {
  *B = om_set8(*B, 2);
}

// [CB D1] SET 2, C
def op_CB_D1() {
  *C = om_set8(*C, 2);
}

// [CB D2] SET 2, D
def op_CB_D2() {
  *D = om_set8(*D, 2);
}

// [CB D3] SET 2, E
def op_CB_D3() {
  *E = om_set8(*E, 2);
}

// [CB D4] SET 2, H
def op_CB_D4() {
  *H = om_set8(*H, 2);
}

// [CB D5] SET 2, L
def op_CB_D5() {
  *L = om_set8(*L, 2);
}

// [CB D6] SET 2, (HL)
def op_CB_D6() {
  mmu_write8(HL, om_set8(mmu_read8(HL), 2));
}

// [CB D7] SET 2, A
def op_CB_D7() {
  *A = om_set8(*A, 2);
}

// [CB D8] SET 3, B
def op_CB_D8() {
  *B = om_set8(*B, 3);
}

// [CB D9] SET 3, C
def op_CB_D9() {
  *C = om_set8(*C, 3);
}

// [CB DA] SET 3, D
def op_CB_DA() {
  *D = om_set8(*D, 3);
}

// [CB DB] SET 3, E
def op_CB_DB() {
  *E = om_set8(*E, 3);
}

// [CB DC] SET 3, H
def op_CB_DC() {
  *H = om_set8(*H, 3);
}

// [CB DD] SET 3, L
def op_CB_DD() {
  *L = om_set8(*L, 3);
}

// [CB DE] SET 3, (HL)
def op_CB_DE() {
  mmu_write8(HL, om_set8(mmu_read8(HL), 3));
}

// [CB DF] SET 3, A
def op_CB_DF() {
  *A = om_set8(*A, 3);
}

// [CB E0] SET 4, B
def op_CB_E0() {
  *B = om_set8(*B, 4);
}

// [CB E1] SET 4, C
def op_CB_E1() {
  *C = om_set8(*C, 4);
}

// [CB E2] SET 4, D
def op_CB_E2() {
  *D = om_set8(*D, 4);
}

// [CB E3] SET 4, E
def op_CB_E3() {
  *E = om_set8(*E, 4);
}

// [CB E4] SET 4, H
def op_CB_E4() {
  *H = om_set8(*H, 4);
}

// [CB E5] SET 4, L
def op_CB_E5() {
  *L = om_set8(*L, 4);
}

// [CB E6] SET 4, (HL)
def op_CB_E6() {
  mmu_write8(HL, om_set8(mmu_read8(HL), 4));
}

// [CB E7] SET 4, A
def op_CB_E7() {
  *A = om_set8(*A, 4);
}

// [CB E8] SET 5, B
def op_CB_E8() {
  *B = om_set8(*B, 5);
}

// [CB E9] SET 5, C
def op_CB_E9() {
  *C = om_set8(*C, 5);
}

// [CB EA] SET 5, D
def op_CB_EA() {
  *D = om_set8(*D, 5);
}

// [CB EB] SET 5, E
def op_CB_EB() {
  *E = om_set8(*E, 5);
}

// [CB EC] SET 5, H
def op_CB_EC() {
  *H = om_set8(*H, 5);
}

// [CB ED] SET 5, L
def op_CB_ED() {
  *L = om_set8(*L, 5);
}

// [CB EE] SET 5, (HL)
def op_CB_EE() {
  mmu_write8(HL, om_set8(mmu_read8(HL), 5));
}

// [CB EF] SET 5, A
def op_CB_EF() {
  *A = om_set8(*A, 5);
}

// [CB F0] SET 6, B
def op_CB_F0() {
  *B = om_set8(*B, 6);
}

// [CB F1] SET 6, C
def op_CB_F1() {
  *C = om_set8(*C, 6);
}

// [CB F2] SET 6, D
def op_CB_F2() {
  *D = om_set8(*D, 6);
}

// [CB F3] SET 6, E
def op_CB_F3() {
  *E = om_set8(*E, 6);
}

// [CB F4] SET 6, H
def op_CB_F4() {
  *H = om_set8(*H, 6);
}

// [CB F5] SET 6, L
def op_CB_F5() {
  *L = om_set8(*L, 6);
}

// [CB F6] SET 6, (HL)
def op_CB_F6() {
  mmu_write8(HL, om_set8(mmu_read8(HL), 6));
}

// [CB F7] SET 6, A
def op_CB_F7() {
  *A = om_set8(*A, 6);
}

// [CB F8] SET 7, B
def op_CB_F8() {
  *B = om_set8(*B, 7);
}

// [CB F9] SET 7, C
def op_CB_F9() {
  *C = om_set8(*C, 7);
}

// [CB FA] SET 7, D
def op_CB_FA() {
  *D = om_set8(*D, 7);
}

// [CB FB] SET 7, E
def op_CB_FB() {
  *E = om_set8(*E, 7);
}

// [CB FC] SET 7, H
def op_CB_FC() {
  *H = om_set8(*H, 7);
}

// [CB FD] SET 7, L
def op_CB_FD() {
  *L = om_set8(*L, 7);
}

// [CB FE] SET 7, (HL)
def op_CB_FE() {
  mmu_write8(HL, om_set8(mmu_read8(HL), 7));
}

// [CB FF] SET 7, A
def op_CB_FF() {
  *A = om_set8(*A, 7);
}

// =============================================================================
// [CP] CPU
// =============================================================================
let cpu_skip;
let cpu_stop = false;

def cpu_init() {
  // Memory
  vram = malloc(0x2000);
  wram = malloc(0x2000);
  oam = malloc(160);
  hram = malloc(127);

  memset(vram, 0, 0x2000);
  memset(wram, 0, 0x2000);
  memset(oam, 0, 160);
  memset(hram, 0, 127);
}

def cpu_fini() {
  // Memory
  free(vram);
  free(wram);
  free(oam);
  free(hram);
}

def cpu_reset() {
  cpu_skip = false;
  cpu_stop = false;

  // CPU variables
  PC = 0x0100;
  SP = 0xFFFE;
  IME = true;
  HALT = false;

  // CPU registers
  AF = 0x01B0;
  BC = 0x0013;
  DE = 0x00D8;
  HL = 0x014D;

  // Timers
  DIV = 0xABCC;

  // (Last) Instruction Time (in cycles)
  CYCLES = 0;

  mmu_write8(0xFF05, 0x00);
  mmu_write8(0xFF06, 0x00);
  mmu_write8(0xFF07, 0x00);
  mmu_write8(0xFF10, 0x80);
  mmu_write8(0xFF11, 0xBF);
  mmu_write8(0xFF12, 0xF3);
  mmu_write8(0xFF14, 0xBF);
  mmu_write8(0xFF16, 0x3F);
  mmu_write8(0xFF17, 0x00);
  mmu_write8(0xFF19, 0xBF);
  mmu_write8(0xFF1A, 0x7F);
  mmu_write8(0xFF1B, 0xFF);
  mmu_write8(0xFF1C, 0x9F);
  mmu_write8(0xFF1E, 0xBF);
  mmu_write8(0xFF20, 0xFF);
  mmu_write8(0xFF21, 0x00);
  mmu_write8(0xFF22, 0x00);
  mmu_write8(0xFF23, 0xBF);
  mmu_write8(0xFF24, 0x77);
  mmu_write8(0xFF25, 0xF3);
  // NOTE: $FF26 should be F0 for SGB
  mmu_write8(0xFF26, 0xF1);
  mmu_write8(0xFF40, 0x91);
  mmu_write8(0xFF42, 0x00);
  mmu_write8(0xFF43, 0x00);
  mmu_write8(0xFF45, 0x00);
  mmu_write8(0xFF47, 0xFC);
  mmu_write8(0xFF48, 0xFF);
  mmu_write8(0xFF49, 0xFF);
  mmu_write8(0xFF4A, 0x00);
  mmu_write8(0xFF4B, 0x00);
  mmu_write8(0xFFFF, 0x00);
}

def cpu_step(): uint8 {
  CYCLES = 0;

  // IF STOP; just return 0
  if cpu_stop {
    // STOP stops the world (until a joypad interrupt)
    // FIXME: Allow joypad to resume STOP
    return 0;
  }

  // IF HALT; just return 4 (cycles)
  if HALT {
    if (IE & IF & 0x1F) == 0 {
      return 4;
    } else {
      HALT = false;
    }
  }

  // STEP -> Interrupts
  if (IE & 0x02) != 0 {
    printf("not implemented: STAT interrupt (enabled)\n");
    exit(0);
  }

  let irq = IF & IE;
  if IME and irq > 0 {
    om_push16(&PC);

    if (irq & 0x01) != 0 {
      // V-Blank
      PC = 0x40;
      IF &= ~0x01;
    } else if (irq & 0x02) != 0 {
      // LCD STAT
      PC = 0x48;
      IF &= ~0x02;
    } else if (irq & 0x04) != 0 {
      // Timer
      PC = 0x50;
      IF &= ~0x04;
    } else if (irq & 0x08) != 0 {
      // Serial
      PC = 0x58;
      IF &= ~0x08;
    } else if (irq & 0x10) != 0 {
      // Joypad
      PC = 0x60;
      IF &= ~0x10;
    }

    CYCLES += 20;
    IME = false;

    if HALT {
      CYCLES += 4;
      HALT = false;
    }
  }

  if IME_pending {
    // Re-enable IME
    IME_pending = false;
    IME = true;
  }

  // Get next opcode
  let opcode = mmu_next8();

  // BUG: Skip instruction when HALT happens with interrupts turned off
  //      and a pending interrupt
  if cpu_skip {
    PC -= 1;
    cpu_skip = false;
  }

  // Check if valid/known instruction
  if *((optable as *int64) + opcode) == 0 {
    printf("error: unknown opcode: $%02X\n", opcode);
    exit(-1);
  }

  // Set instruction time to the base/min
  CYCLES += *(cycletable + opcode);

  if opcode != 0xCB {
    // DEBUG: TRACE
    // printf("PC: $%04X AF: $%04X BC: $%04X DE: $%04X HL: $%04X SP: $%04X\n",
    //   PC - 1,
    //   AF,
    //   BC,
    //   DE,
    //   HL,
    //   SP,
    // );
  }

  // Execute instruction
  (*(optable + opcode))();

  return CYCLES;
}

// =============================================================================
// [SP] Sound
// =============================================================================
def sound_write(address: uint16, value: uint8) {
  // TODO: Implement sound registers
  // Do nothing (for now)
}

def sound_read(address: uint16): uint8 {
  // TODO: Implement sound registers
  // Do nothing (for now)
  return 0x00;
}

// =============================================================================
// [GP] GPU
// =============================================================================
let gpu_mode: uint8;
let gpu_mode_clock: uint16;
let gpu_line: uint8;
let gpu_line_compare: uint8;

let gpu_lcd_enable: bool;
let gpu_window_enable: bool;
let gpu_sprite_enable: bool;
let gpu_bg_enable: bool;

let gpu_stat_lyc_compare_enable: bool = false;
let gpu_stat_oam_enable: bool = false;
let gpu_stat_vblank_enable: bool = false;
let gpu_stat_hblank_enable: bool = false;

// 0=9800-9BFF, 1=9C00-9FFF
let gpu_window_tm_select: bool;
let gpu_bg_tm_select: bool;

// 0=8800-97FF, 1=8000-8FFF
let gpu_td_select: bool;

// 0=8x8, 1=8x16
let gpu_sprite_size: bool;

// Framebuffer
let gpu_framebuffer: *uint8;
let framebuffer: *uint32;

// Scrolling
let gpu_scy = 0;
let gpu_scx = 0;

// Window
let gpu_wy = 0;
let gpu_wx = 7;

// Palette
let gpu_palette: uint8 = 0;

// Sprites
let gpu_obj0_palette: uint8 = 0;
let gpu_obj1_palette: uint8 = 0;

def gpu_init() {
  gpu_framebuffer = malloc(160 * 144);
  memset(gpu_framebuffer, 0, 160 * 144);

  framebuffer = malloc(160 * 144 * 4) as *uint32;
  memset(framebuffer as *uint8, 0, 160 * 144 * 4);
}

def gpu_fini() {
  free(gpu_framebuffer);
  free(framebuffer as *uint8);
}

def gpu_reset() {
  gpu_mode = 2;
  gpu_mode_clock = 0;
  gpu_line = 0;
}

def gpu_sprite_compare(a: *uint8, b: *uint8): c_int {
  let a_x = *(a + 1);
  let b_x = *(b + 1);

  if a_x < b_x {
    return -1;
  }

  if b_x > a_x {
    return 1;
  }

  if a_x == b_x {
    let aptr = a as uint64;
    let bptr = b as uint64;

    if aptr < bptr {
      return -1;
    }

    if bptr > aptr {
      return 1;
    }
  }

  return 0;
}

def gpu_render_scanline() {
  // TODO: Combine Window & Background rendering .. code is super duplicated

  // Set whole line to 0x0 (clear)
  let i = 0;
  while i < 160 {
    *(gpu_framebuffer + (int64(gpu_line) * 160) + i) = 0;

    i += 1;
  }

  // Background
  if gpu_bg_enable {
    // Line (to be rendered)
    // With a high SCY value, the line wraps around
    let line = (int64(gpu_line) + int64(gpu_scy)) & 0xFF;

    // Tile Map (Offset)
    // The tile map is 32x32 (1024 bytes) and is an index into the tile data
    // A single tile map cell corresponds to an 8x8 cell in the framebuffer
    //  map 0 ~ line 0..7
    //  map 31 ~ line 8..13
    let map: int64 = if (gpu_bg_tm_select) { 0x1C00; } else { 0x1800; };
    map += (line >> 3) << 5;

    let i: int64 = 0;
    let x = gpu_scx % 8;
    let offset = int64(gpu_scx) >> 3;
    let y = line % 8;

    let i = 0;
    while i < 160 {
      if (x == 8) {
        // New Tile
        x = 0;
        offset = (offset + 1) % 32;
      }

      // Tile Map
      let tile: int16;
      if gpu_td_select {
        tile = int16(*(vram + map + offset));
      } else {
        tile = int16(int8(*(vram + map + offset))) + 256;
      }

      let pixel = gpu_get_tile_pixel(tile, uint8(x), uint8(y));
      let color = (gpu_palette >> (pixel * 2)) & 0x3;

      // Push pixel to framebuffer
      *(gpu_framebuffer + (int64(gpu_line) * 160) + i) = color;

      x += 1;
      i += 1;
    }
  } else {
    // Background not enabled
    // FIXME: Should we do anything special here?
  }

  // Window
  if gpu_window_enable {
    // FIXME: What is supposed to happen when WX is set to < 7 ?
    let wx = if gpu_wx < 7 { 0; } else { gpu_wx - 7; };
    let wy = gpu_wy;

    // Line (to be rendered)
    let line = int64(gpu_line);
    if line > int64(wy) {

      // Tile Map (Offset)
      // The tile map is 32x32 (1024 bytes) and is an index into the tile data
      // A single tile map cell corresponds to an 8x8 cell in the framebuffer
      //  map 0 ~ line 0..7
      //  map 31 ~ line 8..13
      let map: int64 = if (gpu_window_tm_select) { 0x1C00; } else { 0x1800; };
      map += ((line - int64(wy)) >> 3) << 5;

      let i: int64 = 0;
      let x = 0;
      let offset = 0;
      let y = line % 8;

      let i = wx;
      while i < 160 {
        if (x == 8) {
          // New Tile
          x = 0;
          offset = (offset + 1) % 32;
        }

        // Tile Map
        let tile: int16;
        if gpu_td_select {
          tile = int16(*(vram + map + offset));
        } else {
          tile = int16(int8(*(vram + map + offset))) + 256;
        }

        let pixel = gpu_get_tile_pixel(tile, uint8(x), uint8(y));
        let color = (gpu_palette >> (pixel * 2)) & 0x3;

        *(gpu_framebuffer + (int64(gpu_line) * 160) + i) = color;

        x += 1;
        i += 1;
      }
    }
  } else {
    // Window not enabled
    // FIXME: Should we do anything special here?
  }

  // Sprites
  if gpu_sprite_enable {

    // Sprite attributes reside in the Sprite Attribute Table (
    // OAM - Object Attribute Memory) at $FE00-FE9F.
    // Each of the 40 entries consists of four bytes with the
    // following meanings:
    //  Byte0 - Y Position
    //  Byte1 - X Position
    //  Byte2 - Tile/Pattern Number
    //  Byte3 - Attributes/Flags:
    //    Bit7   OBJ-to-BG Priority (0=OBJ Above BG, 1=OBJ Behind BG color 1-3)
    //           (Used for both BG and Window. BG color 0 is always behind OBJ)
    //    Bit6   Y flip          (0=Normal, 1=Vertically mirrored)
    //    Bit5   X flip          (0=Normal, 1=Horizontally mirrored)
    //    Bit4   Palette number  **Non CGB Mode Only** (0=OBP0, 1=OBP1)
    //    Bit3   Tile VRAM-Bank  **CGB Mode Only**     (0=Bank 0, 1=Bank 1)
    //    Bit2-0 Palette number  **CGB Mode Only**     (OBP0-7)

    let sprite_size = if gpu_sprite_size { 16; } else { 8; };

    // // Sort the sprite table by priority
    // let oam_c = malloc(40 * 4);
    // memcpy(oam_c, oam, 40 * 4);
    // qsort(oam_c, 40, 4, gpu_sprite_compare);
    let total = 0;

    let i = 0;
    while i < 40 {
      let offset = (i * 4);

      let sy = int16(*(oam + offset + 0)) - 16;
      let sx = int16(*(oam + offset + 1)) - 8;
      let sprite_tile = int16(*(oam + offset + 2));
      let sprite_flags = *(oam + offset + 3);

      // Remember, we are rendering on a line-by-line basis
      // Does this sprite intersect our current scanline?

      if sy <= int16(gpu_line) and (sy + sprite_size) > int16(gpu_line) {

        total += 1;
        if total > 10 {
          break;
        }

        let tile_y: int16 = int16(gpu_line) - sy;
        if testb(sprite_flags, 6) {
          tile_y = sprite_size - 1 - tile_y;
        }

        // IFF sprite_size is 16 ..
        if sprite_size == 16 {
          // Top or bottom tile?
          if tile_y < 8 {
            // Top
            sprite_tile &= 0xFE;
          } else {
            // Bottom
            tile_y -= 8;
            sprite_tile |= 0x01;
          }
        }

        // Iterate through the columns of the sprite pixels and
        // blit them on the scanline

        let x: int16 = 0;
        while x < 8 {
          if (sx + x >= 0) and (sx + x < 160) {
            let pixel = gpu_get_tile_pixel(
              sprite_tile,
              uint8(if testb(sprite_flags, 5) { 7 - x; } else { x; }),
              uint8(tile_y));

            // NOTE: 0 is transparent for sprites
            if pixel != 0 {
              // Palette
              let color = if testb(sprite_flags, 4) {
                (gpu_obj1_palette >> (pixel << 1)) & 0x3;
              } else {
                (gpu_obj0_palette >> (pixel << 1)) & 0x3;
              };

              // Push pixel to framebuffer
              let fbo: int64 = (int64(gpu_line) * 160) + int64(sx + x);
              if testb(sprite_flags, 7) {
                let bgcolor = *(gpu_framebuffer + fbo);
                if bgcolor == 0 {
                  *(gpu_framebuffer + fbo) = color;
                }
              } else {
                *(gpu_framebuffer + fbo) = color;
              }
            }
          }

          x += 1;
        }
      }

      i += 1;
    }

    // Free temp OAM
    // free(oam_c);
  } else {
    // Sprites not enabled
    // FIXME: Should we do anything special here?
  }
}

def gpu_get_tile_pixel(tile: int16, x: uint8, y: uint8): uint8 {
  let offset: int16 = tile * 16 + int16(y) * 2;

  return (
    ((*(vram + offset + 1) >> (7 - x) << 1) & 2) |
    ((*(vram + offset + 0) >> (7 - x)) & 1));
}

def gpu_present() {
  // Screen is 160x144
  let y = 0;

  while y < 144 {
    let x = 0;

    while x < 160 {
      let pixel = *(gpu_framebuffer + (y * 160 + x));

      // AARRGGBB
      let color: uint32 = if pixel == 0 {
        // Grayscale
        0xFFFFFFFF;
        // Green
        // 0xFF9BBC0F;
        // Yellow
        // 0xFFFFFD4B;
      } else if pixel == 1 {
        // Grayscale
        0xFFC0C0C0;
        // Green
        // 0xFF8BB30F;
        // Yellow
        // 0xFFABA92F;
      } else if pixel == 2 {
        // Grayscale
        0xFF606060;
        // Green
        // 0xFF306230;
        // Yellow
        // 0xFF565413;
      } else if pixel == 3 {
        // Grayscale
        0xFF000000;
        // Green
        // 0xFF0F410F;
        // Yellow
        // 0xFF000000;
      } else {
        0;
      };

      *(framebuffer + (y * 160 + x)) = color;

      x += 1;
    }

    y += 1;
  }
}

def gpu_step(cycles: uint8): bool {
  gpu_mode_clock += uint16(cycles);
  let vblank = false;

  if gpu_lcd_enable {
    if gpu_mode == 2 {
      // Scanline: OAM read mode
      if gpu_mode_clock >= 80 {
        gpu_mode = 3;
        gpu_mode_clock -= 80;
      }
    } else if gpu_mode == 3 {
      // Scanline: VRAM read mode
      if gpu_mode_clock >= 172 {
        gpu_mode = 0;
        gpu_mode_clock -= 172;

        // Render Scanline
        gpu_render_scanline();
      }
    } else if gpu_mode == 0 {
      // HBLANK
      if gpu_mode_clock >= 204 {
        gpu_mode_clock -= 204;

        if gpu_line == 143 {
          gpu_mode = 1;
          vblank = true;

          // VBLANK Interrupt
          IF |= 0x01;
        } else {
          gpu_mode = 2;
        }

        gpu_line += 1;
      }
    } else if gpu_mode == 1 {
      // VBLANK
      if gpu_mode_clock >= 456 {
        gpu_mode_clock -= 456;

        if gpu_line == 0 {
          gpu_line = 0;
          gpu_mode = 2;
        } else {
          gpu_line += 1;
        }
      } else if gpu_line == 153 and gpu_mode_clock >= 4 {
        gpu_line = 0;
      }
    }
  } else {
    if gpu_mode_clock >= 70224 {
      gpu_mode_clock -= 70224;
      vblank = true;
    }
  }

  return vblank;
}

def gpu_read(address: uint16): uint8 {
  if address == 0xFF40 {
    // LCDC - LCD Control (R/W)
    return (
      bit(gpu_lcd_enable, 7) |
      bit(gpu_window_tm_select, 6) |
      bit(gpu_window_enable, 5) |
      bit(gpu_td_select, 4) |
      bit(gpu_bg_tm_select, 3) |
      bit(gpu_sprite_size, 2) |
      bit(gpu_sprite_enable, 1) |
      bit(gpu_bg_enable, 0)
    );
  } else if address == 0xFF41 {
    // STAT – LCDC Status (R/W)
    return (
      bit(true, 7) |
      bit(gpu_stat_lyc_compare_enable, 6) |
      bit(gpu_stat_oam_enable, 5) |
      bit(gpu_stat_vblank_enable, 4) |
      bit(gpu_stat_hblank_enable, 3) |
      bit(gpu_line == gpu_line_compare, 2) |
      uint8(gpu_mode)
    );
  } else if address == 0xFF42 {
    // SCY – Scroll Y (R/W)
    return gpu_scy;
  } else if address == 0xFF43 {
    // SCX – Scroll X (R/W)
    return gpu_scx;
  } else if address == 0xFF44 {
    // LY – LCDC Y-Coordinate (R)
    // FIXME
    return 0xFF;
    // return gpu_line;
  } else if address == 0xFF45 {
    // LYC – LY Compare (R/W)
    return gpu_line_compare;
  } else if address == 0xFF47 {
    // BGP – Background Palette (R/W)
    return gpu_palette;
  } else if address == 0xFF4A {
    // WY – Window Y Position (R/W)
    return gpu_wy;
  } else if address == 0xFF4B {
    // WX – Window X Position (R/W)
    return gpu_wx;
  } else if address == 0xFF48 {
    // OBP0 - Object Palette 0 Data (R/W)
    return gpu_obj0_palette;
  } else if address == 0xFF49 {
    // OBP1 - Object Palette 1 Data (R/W)
    return gpu_obj1_palette;
  }

  printf("warn: unhandled read from GPU register: $%04X\n", address);
  return 0xFF;
}

def gpu_write(address: uint16, value: uint8) {
  if address == 0xFF40 {
    // LCDC - LCD Control (R/W)
    if testb(value, 7) ^ gpu_lcd_enable {
      gpu_line = 0;
      gpu_mode = 0;
      gpu_mode_clock = 0;
    }

    gpu_lcd_enable = testb(value, 7);
    gpu_window_tm_select = testb(value, 6);
    gpu_window_enable = testb(value, 5);
    gpu_td_select = testb(value, 4);
    gpu_bg_tm_select = testb(value, 3);
    gpu_sprite_size = testb(value, 2);
    gpu_sprite_enable = testb(value, 1);
    gpu_bg_enable = testb(value, 0);
  } else if address == 0xFF41 {
    // STAT – LCDC Status (R/W)
    gpu_stat_lyc_compare_enable = testb(value, 6);
    gpu_stat_oam_enable = testb(value, 5);
    gpu_stat_vblank_enable = testb(value, 4);
    gpu_stat_hblank_enable = testb(value, 3);
  } else if address == 0xFF42 {
    // SCY – Scroll Y (R/W)
    gpu_scy = value;
  } else if address == 0xFF43 {
    // SCX – Scroll X (R/W)
    gpu_scx = value;
  } else if address == 0xFF45 {
    // LYC – LY Compare (R/W)
    gpu_line_compare = value;
  } else if address == 0xFF47 {
    // BGP – Background Palette (R/W)
    gpu_palette = value;
  } else if address == 0xFF4A {
    // WY – Window Y Position (R/W)
    gpu_wy = value;
  } else if address == 0xFF4B {
    // WX – Window X Position (R/W)
    gpu_wx = value;
  } else if address == 0xFF46 {
    // DMA - DMA Transfer and Start Address (W)

    // FIXME: This is supposed to take 160 × 4 + 4 cycles to complete
    //        4 cycles to begin with 4 cycles per write/read (transfer)

    let src = uint16(value) << 8;
    if src >= 0x8000 and src < 0xE000 {
      let i: uint16 = 0;
      while i < 0xA0 {
        mmu_write8(0xFE00 + i, mmu_read8(src + i));

        i += 1;
      }
    }
  } else if address == 0xFF48 {
    // OBP0 - Object Palette 0 Data (R/W)
    gpu_obj0_palette = value;
  } else if address == 0xFF49 {
    // OBP1 - Object Palette 1 Data (R/W)
    gpu_obj1_palette = value;
  } else {
    printf("warn: unhandled write to GPU register: $%04X ($%02X)\n",
      address, value);
  }
}

// =============================================================================
// [IN] Input / Joypad
// =============================================================================
let joy_sel_button = false;
let joy_sel_direction = false;

// 1 - Pressed
let joy_state_start = true;
let joy_state_sel = true;
let joy_state_a = false;
let joy_state_b = false;
let joy_state_up = false;
let joy_state_down = false;
let joy_state_left = false;
let joy_state_right = false;

def joy_reset() {
  joy_sel_button = true;
  joy_sel_direction = true;

  joy_state_start = false;
  joy_state_sel = false;
  joy_state_a = false;
  joy_state_b = false;
  joy_state_up = false;
  joy_state_down = false;
  joy_state_left = false;
  joy_state_right = false;
}

def joy_write(address: uint16, value: uint8) {
  if address == 0xFF00 {
    joy_sel_button = not testb(value, 5);
    joy_sel_direction = not testb(value, 4);
  } else {
    printf("warn: unhandled write to Joypad register: $%04X ($%02X)\n",
      address, value);
  }
}

def joy_read(address: uint16): uint8 {
  if address == 0xFF00 {
    // P1 – Joypad (R/W)
    // Bit 7 - Not used
    // Bit 6 - Not used
    // Bit 5 - P15 Select Button Keys      (0=Select)
    // Bit 4 - P14 Select Direction Keys   (0=Select)
    // Bit 3 - P13 Input Down  or Start    (0=Pressed) (Read Only)
    // Bit 2 - P12 Input Up    or Select   (0=Pressed) (Read Only)
    // Bit 1 - P11 Input Left  or Button B (0=Pressed) (Read Only)
    // Bit 0 - P10 Input Right or Button A (0=Pressed) (Read Only)

    // NOTE: This is backwards logic to me. 0 = True ?
    return (
      bit(true, 7) |
      bit(true, 6) |
      bit(not joy_sel_button, 5) |
      bit(not joy_sel_direction, 4) |
      bit(not ((joy_sel_button and joy_state_start) or (joy_sel_direction and joy_state_down)), 3) |
      bit(not ((joy_sel_button and joy_state_sel) or (joy_sel_direction and joy_state_up)), 2) |
      bit(not ((joy_sel_button and joy_state_b) or (joy_sel_direction and joy_state_left)), 1) |
      bit(not ((joy_sel_button and joy_state_a) or (joy_sel_direction and joy_state_right)), 0)
    );
  } else {
    printf("warn: unhandled read from Joypad register: $%04X\n", address);
    return 0xFF;
  }
}

// =============================================================================
// [CX] Core
// =============================================================================
def execute() {
  while is_running {
    // STEP -> CPU
    let cycles = cpu_step();

    div_timer_step(cycles);

    // STEP -> GPU
    let vblank = gpu_step(cycles);

    if vblank {
      // Poll window events
      sdl_step();

      if gpu_lcd_enable {
        // Rasterize framebuffer
        gpu_present();

        // Blit pixels
        sdl_render();
      }
    }
  }
}

// =============================================================================
// [SD] SDL
// =============================================================================

extern def SDL_Init(flags: uint32): c_int;
extern def SDL_Quit();

extern def SDL_CreateWindow(
  title: str,
  x: c_int, y: c_int,
  width: c_int, height: c_int,
  flags: uint32
): *uint8;

extern def SDL_CreateRenderer(window: *uint8, index: c_int, flags: uint32): *uint8;
extern def SDL_CreateTexture(renderer: *uint8, format: uint32, access: c_int, w: c_int, h: c_int): *uint8;

extern def SDL_DestroyWindow(window: *uint8);
extern def SDL_DestroyRenderer(renderer: *uint8);
extern def SDL_DestroyTexture(texture: *uint8);

extern def SDL_RenderClear(renderer: *uint8);
extern def SDL_SetRenderDrawColor(renderer: *uint8, r: uint8, g: uint8, b: uint8, a: uint8);
extern def SDL_RenderDrawPoint(renderer: *uint8, x: c_int, y: c_int);
extern def SDL_RenderPresent(renderer: *uint8);
extern def SDL_RenderCopy(renderer: *uint8, texture: *uint8, src: *uint8, dst: *uint8);

extern def SDL_UpdateTexture(texture: *uint8, rect: *uint8, pixels: *uint8, pitch: c_int);

extern def SDL_Delay(ms: uint32);

extern def SDL_PollEvent(evt: *uint8): bool;

let SDL_TEXTUREACCESS_STREAMING: c_int = 1;

let SDL_INIT_VIDEO: uint32 = 0x00000020;

let SDL_WINDOW_SHOWN: uint32 = 0x00000004;

let SDL_RENDERER_ACCELERATED: uint32 = 0x00000002;
let SDL_RENDERER_PRESENTVSYNC: uint32 = 0x00000004;

let SDL_PIXELFORMAT_ARGB8888: uint32 = 372645892;

let _evt: *uint8;
let _window: *uint8;
let _tex: *uint8;
let _renderer: *uint8;

def sdl_init() {
  // HACK!! We need structs
  _evt = malloc(1000);

  // Initialize SDL
  SDL_Init(SDL_INIT_VIDEO);

  // Create Window
  // TODO: Allow scaling
  _window = SDL_CreateWindow(
    "Wadatsumi", 0x1FFF0000, 0x1FFF0000, 160 * 4, 144 * 4, SDL_WINDOW_SHOWN);

  // Create renderer
  _renderer = SDL_CreateRenderer(_window, -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

  // White initial screen
  SDL_SetRenderDrawColor(_renderer, 155, 188, 15, 255);
  // SDL_SetRenderDrawColor(_renderer, 255, 255, 255, 255);
  SDL_RenderClear(_renderer);
  SDL_RenderPresent(_renderer);

  // Create texture
  _tex = SDL_CreateTexture(_renderer,
    SDL_PIXELFORMAT_ARGB8888,
    SDL_TEXTUREACCESS_STREAMING,
    160, 144);
}

def sdl_fini() {
  free(_evt);

  SDL_DestroyRenderer(_renderer);
  SDL_DestroyWindow(_window);
  SDL_DestroyTexture(_tex);
  SDL_Quit();
}

def sdl_render() {
  // Render
  SDL_SetRenderDrawColor(_renderer, 155, 188, 15, 255);
  // SDL_SetRenderDrawColor(_renderer, 255, 255, 255, 255);
  SDL_RenderClear(_renderer);

  SDL_UpdateTexture(_tex, 0 as *uint8, framebuffer as *uint8, 160 * 4);
  SDL_RenderCopy(_renderer, _tex, 0 as *uint8, 0 as *uint8);

  SDL_RenderPresent(_renderer);
}

def sdl_step() {
  // Events
  if SDL_PollEvent(_evt) {
    let evt_type = *(_evt as *uint32);
    if evt_type == 0x100 {
      // Quit – App was asked to quit (nicely)
      is_running = false;
    } else if evt_type == 0x300 or evt_type == 0x301 {
      // Key Up/Down Event
      let code = int64(*(((_evt as *uint8) + 16) as *c_int));
      let pressed = (evt_type == 0x300);
      if code == 40 {
        // START => ENTER (US Keyboard)
        joy_state_start = pressed;
      } else if code == 29 {
        // A => Z (US Keyboard)
        joy_state_a = pressed;
      } else if code == 27 {
        // B => X (US Keyboard)
        joy_state_b = pressed;
      } else if code == 225 {
        // SELECT => LEFT SHIFT (US Keyboard)
        joy_state_sel = pressed;
      } else if code == 82 {
        // UP => UP ARROW (US Keyboard)
        joy_state_up = pressed;
      } else if code == 81 {
        // DOWN => DOWN ARROW (US Keyboard)
        joy_state_down = pressed;
      } else if code == 80 {
        // LEFT => LEFT ARROW (US Keyboard)
        joy_state_left = pressed;
      } else if code == 79 {
        // RIGHT => RIGHT ARROW (US Keyboard)
        joy_state_right = pressed;
      }
    }
  }
}

// =============================================================================
// Timers
// =============================================================================
def div_timer_step(cycles: uint8) {
  let cycle:uint8 = 0;
  let TACBit:uint16 = 0;
  let oldBit:uint16 = 0;

  if (TAC > 4) {
    // If we have the TAC enable bit set, then we need to check for a 1 - 0
    // conversion on a specific bit. This figures out which bit.
    if (TAC & 0x03) == 0 {
      TACBit = 0x2000;
    } else {
      TACBit = 0x0001 << ((TAC & 0x03) * 2 + 1);
    }
    oldBit = DIV & TACBit;
  }


  while cycle < cycles {
    DIV += 1;
    // Handle TIMA inc if needed
    if TACBit > 0 and oldBit > 0 and DIV & TACBit == 0 {
      TIMA += 1;
      if TIMA == 0 {
        // We've overflowed
        TIMA = TMA;
        IF = IF | 0x04;
      }
    }

    cycle += 1;
    oldBit = DIV & TACBit;
  }
}

def timer_write(address: uint16, value: uint8) {
  if address == 0xFF04 {
    DIV = 0;
    return;
  }

  if address == 0xFF05 {
    // TIMA
    TIMA = value;
    return;
  }

  if address == 0xFF06 {
    // TMA
    TMA = value;
    return;
  }

  if address == 0xFF07 {
    // TMC
    // We only care about the last 3 bits
    TAC = value & 0x07;
    // printf("warn: TAC Written to: $%02X ($%02X)\n", value, TAC);
    return;
  }
}
