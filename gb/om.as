import "./cpu";
import "libc";

// Flags
// =============================================================================

type Flag = uint8;

let FLAG_Z: Flag = 0b1000_0000;
let FLAG_N: Flag = 0b0100_0000;
let FLAG_H: Flag = 0b0010_0000;
let FLAG_C: Flag = 0b0001_0000;

def flag_set(c: *cpu.CPU, flag: Flag, value: bool) {
  if value { *(c.F) |=  uint8(flag); }
  else     { *(c.F) &= ~uint8(flag); }
}

def flag_get(c: *cpu.CPU, flag: Flag): bool {
  return *(c.F) & uint8(flag) != 0;
}

def flag_geti(c: *cpu.CPU, flag: Flag): uint8 {
  return if flag_get(c, flag) { 1; } else { 0; };
}

// Microcode
// =============================================================================

// Read Next 8-bit
def readNext8(c: *cpu.CPU): uint8 {
  let value = read8(c, c.PC);
  c.PC += 1;

  return value;
}

// Read 8-bit
def read8(c: *cpu.CPU, address: uint16): uint8 {
  let value = 0xFF;

  // IF during OAM DMA; only HIRAM is accessible
  if c.OAM_DMA_Timer == 0 or (address >= 0xFF80 and address <= 0xFFFE) {
    value = c.MMU.Read(address);
  }

  c.Tick();

  return value;
}

// Read Next 16-bit
def readNext16(c: *cpu.CPU): uint16 {
  let value = read16(c, c.PC);
  c.PC += 2;

  return value;
}

// Read 16-bit
def read16(c: *cpu.CPU, address: uint16): uint16 {
  let l = read8(c, address + 0);
  let h = read8(c, address + 1);

  let value = uint16(l) | (uint16(h) << 8);
  return value;
}

// Write 16-bit
def write16(c: *cpu.CPU, address: uint16, value: uint16) {
  write8(c, address + 0, uint8(value & 0xFF));
  write8(c, address + 1, uint8(value >> 8));
}

// Write 8-bit
def write8(c: *cpu.CPU, address: uint16, value: uint8) {
  // IF during OAM DMA; writes are ignored unless the address
  // is 0xFF46 (OAM DMA restart) or in HIRAM
  if c.OAM_DMA_Timer == 0 or address == 0xFF46 or (address >= 0xFF80 and address <= 0xFFFE) {
    c.MMU.Write(address, value);
  }

  c.Tick();
}

// Increment 8-bit
def inc8(c: *cpu.CPU, value: uint8): uint8 {
  value += 1;

  flag_set(c, FLAG_Z, value == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, value & 0x0F == 0x00);

  return value;
}

// Decrement 8-bit
def dec8(c: *cpu.CPU, value: uint8): uint8 {
  value -= 1;

  flag_set(c, FLAG_Z, value == 0);
  flag_set(c, FLAG_N, true);
  flag_set(c, FLAG_H, value & 0x0F == 0x0F);

  return value;
}

// And 8-bit value
def and8(c: *cpu.CPU, a: uint8, b: uint8): uint8 {
  let r = a & b;

  flag_set(c, FLAG_Z, r == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, true);
  flag_set(c, FLAG_C, false);

  return r;
}

// Or 8-bit value
def or8(c: *cpu.CPU, a: uint8, b: uint8): uint8 {
  let r = a | b;

  flag_set(c, FLAG_Z, r == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, false);
  flag_set(c, FLAG_C, false);

  return r;
}

// Xor 8-bit value
def xor8(c: *cpu.CPU, a: uint8, b: uint8): uint8 {
  let r = a ^ b;

  flag_set(c, FLAG_Z, r == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, false);
  flag_set(c, FLAG_C, false);

  return r;
}

// Add 8-bit value
def add8(c: *cpu.CPU, a: uint8, b: uint8): uint8 {
  let r = uint16(a) + uint16(b);

  flag_set(c, FLAG_H, ((a & 0x0F) + (b & 0x0F)) > 0x0F);
  flag_set(c, FLAG_Z, (r & 0xFF) == 0);
  flag_set(c, FLAG_C, r > 0xFF);
  flag_set(c, FLAG_N, false);

  return uint8(r & 0xFF);
}

// Add 8-bit value w/carry
def adc8(c: *cpu.CPU, a: uint8, b: uint8): uint8 {
  let carry = uint16(flag_geti(c, FLAG_C));
  let r = uint16(a) + uint16(b) + carry;

  flag_set(c, FLAG_H, ((a & 0x0F) + (b & 0x0F) + uint8(carry)) > 0x0F);
  flag_set(c, FLAG_Z, (r & 0xFF) == 0);
  flag_set(c, FLAG_C, r > 0xFF);
  flag_set(c, FLAG_N, false);

  return uint8(r & 0xFF);
}

// Subtract 8-bit value
def sub8(c: *cpu.CPU, a: uint8, b: uint8): uint8 {
  let r = int16(a) - int16(b);

  flag_set(c, FLAG_C, r < 0);
  flag_set(c, FLAG_Z, (r & 0xFF) == 0);
  flag_set(c, FLAG_N, true);
  flag_set(c, FLAG_H, (((int16(a) & 0x0F) - (int16(b) & 0x0F)) < 0));

  return uint8(r & 0xFF);
}

// Subtract 8-bit value w/carry
def sbc8(c: *cpu.CPU, a: uint8, b: uint8): uint8 {
  let carry = int16(flag_geti(c, FLAG_C));
  let r = int16(a) - int16(b) - carry;

  flag_set(c, FLAG_C, r < 0);
  flag_set(c, FLAG_Z, (r & 0xFF) == 0);
  flag_set(c, FLAG_N, true);
  flag_set(c, FLAG_H, (((int16(a) & 0x0F) - (int16(b) & 0x0F) - carry) < 0));

  return uint8(r & 0xFF);
}

// Add 16-bit value
def add16(c: *cpu.CPU, a: uint16, b: uint16): uint16 {
  let r = uint32(a) + uint32(b);

  flag_set(c, FLAG_H, ((a ^ b ^ uint16(r & 0xFFFF)) & 0x1000) != 0);
  flag_set(c, FLAG_C, r > 0xFFFF);
  flag_set(c, FLAG_N, false);

  return uint16(r & 0xFFFF);
}

// Push 16-bit value
def push16(c: *cpu.CPU, r: *uint16) {
  c.SP -= 2;
  write16(c, c.SP, *r);
}

// Pop 16-bit value
def pop16(c: *cpu.CPU, r: *uint16) {
  *r = read16(c, c.SP);
  c.SP += 2;
}

// Jump
def jp(c: *cpu.CPU, address: uint16, tick: bool) {
  c.PC = address;
  if tick { c.Tick(); }
}

// Relative Jump
// 7-bit relative jump address with a sign bit to indicate +/-
def jr(c: *cpu.CPU, n: uint8) {
  jp(c, uint16(int16(c.PC) + int16(int8(n))), true);
}

// Call
def call(c: *cpu.CPU, address: uint16) {
  push16(c, &c.PC);
  jp(c, address, true);
}

// Return
def ret(c: *cpu.CPU) {
  pop16(c, &c.PC);
  c.Tick();
}

// Byte Swap
def swap8(c: *cpu.CPU, n: uint8): uint8 {
  let r = (n >> 4) | ((n << 4) & 0xF0);

  flag_set(c, FLAG_Z, r == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, false);
  flag_set(c, FLAG_C, false);

  return r;
}

// Shift Right
def shr(c: *cpu.CPU, n: uint8, arithmetic: bool): uint8 {
  let r = if arithmetic {
    if (n & 0x80) != 0 {
      (n >> 1) | 0x80;
    } else {
      (n >> 1);
    }
  } else {
    (n >> 1);
  };

  flag_set(c, FLAG_Z, r == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, false);
  flag_set(c, FLAG_C, (n & 0x01) != 0);

  return r;
}

// Shift Left
def shl(c: *cpu.CPU, n: uint8): uint8 {
  let r = (n << 1);

  flag_set(c, FLAG_Z, r == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, false);
  flag_set(c, FLAG_C, (n & 0x80) != 0);

  return r;
}

// Rotate Left (opt. through carry)
def rotl8(c: *cpu.CPU, n: uint8, carry: bool): uint8 {
  let r = if carry {
    (n << 1) | flag_geti(c, FLAG_C);
  } else {
    (n << 1) | (n >> 7);
  };

  flag_set(c, FLAG_Z, r == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, false);
  flag_set(c, FLAG_C, ((n & 0x80) != 0));

  return r;
}

// Rotate Right (opt. through carry)
def rotr8(c: *cpu.CPU, n: uint8, carry: bool): uint8 {
  let r = if carry {
    (n >> 1) | (flag_geti(c, FLAG_C) << 7);
  } else {
    (n >> 1) | (n << 7);
  };

  flag_set(c, FLAG_Z, r == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, false);
  flag_set(c, FLAG_C, ((n & 0x01) != 0));

  return r;
}

// Bit Test
def bit8(c: *cpu.CPU, n: uint8, b: uint8) {
  flag_set(c, FLAG_Z, (n & (1 << b)) == 0);
  flag_set(c, FLAG_N, false);
  flag_set(c, FLAG_H, true);
}

// Bit Set
def set8(c: *cpu.CPU, n: uint8, b: uint8): uint8 {
  return n | (1 << b);
}

// Bit Reset
def res8(c: *cpu.CPU, n: uint8, b: uint8): uint8 {
  return n & ~(1 << b);
}
