import "std";
import "libc";

struct Context {
  // 16 General Registers
  V: *uint8;

  // Index Register (16-bit)
  I: uint16;

  // Stack Pointer
  SP: uint8;

  // Program Counter (12-bit)
  PC: uint16;

  // Timers — Automatically decremented at 60 Hz
  ST: uint8;
  DT: uint8;

  // Stack (16 16-bit Slots) — SP is used to index into it
  stack: *uint16;

  // The CHIP-8 has 3.5 KiB of accessible RAM (no memory protections)
  // THe program ROM is loaded directly at $0
  ram: *uint8;

  // FONT sprie memory
  font: *uint8;

  // Screen Size
  width: uint16;
  height: uint16;

  // Framebuffer
  framebuffer: *uint8;
}

def new_context(): Context {
  let c: Context;
  libc.memset(&c as *uint8, 0, std.size_of<Context>());

  c.V = libc.malloc(0x10);
  c.stack = libc.malloc(0x10 * 2) as *uint16;
  c.ram = libc.malloc(0x1000);
  c.framebuffer = libc.malloc(64 * 32);
  c.font = libc.malloc(16 * 5);

  libc.memset(c.framebuffer, 0, 64 * 32);

  // HACK: This should go elsewhere
  c.width = 64;
  c.height = 32;

  // Load FONT sprites into Font RAM
  *(c.font + 0x00) = 0xF0;  // 0
  *(c.font + 0x01) = 0x90;
  *(c.font + 0x02) = 0x90;
  *(c.font + 0x03) = 0x90;
  *(c.font + 0x04) = 0xF0;

  *(c.font + 0x05) = 0x20;  // 1
  *(c.font + 0x06) = 0x60;
  *(c.font + 0x07) = 0x20;
  *(c.font + 0x08) = 0x20;
  *(c.font + 0x09) = 0x70;

  *(c.font + 0x0A) = 0xF0;  // 2
  *(c.font + 0x0B) = 0x10;
  *(c.font + 0x0C) = 0xF0;
  *(c.font + 0x0D) = 0x80;
  *(c.font + 0x0E) = 0xF0;

  *(c.font + 0x0F) = 0xF0;  // 3
  *(c.font + 0x10) = 0x10;
  *(c.font + 0x11) = 0xF0;
  *(c.font + 0x12) = 0x10;
  *(c.font + 0x13) = 0xF0;

  *(c.font + 0x14) = 0x90;  // 4
  *(c.font + 0x15) = 0x90;
  *(c.font + 0x16) = 0xF0;
  *(c.font + 0x17) = 0x10;
  *(c.font + 0x18) = 0x10;

  *(c.font + 0x19) = 0xF0;  // 5
  *(c.font + 0x1A) = 0x80;
  *(c.font + 0x1B) = 0xF0;
  *(c.font + 0x1C) = 0x10;
  *(c.font + 0x1D) = 0xF0;

  *(c.font + 0x1E) = 0xF0;  // 6
  *(c.font + 0x1F) = 0x80;
  *(c.font + 0x20) = 0xF0;
  *(c.font + 0x21) = 0x90;
  *(c.font + 0x22) = 0xF0;

  *(c.font + 0x23) = 0xF0;  // 7
  *(c.font + 0x24) = 0x10;
  *(c.font + 0x25) = 0x20;
  *(c.font + 0x26) = 0x40;
  *(c.font + 0x27) = 0x40;

  *(c.font + 0x28) = 0xF0;  // 8
  *(c.font + 0x29) = 0x90;
  *(c.font + 0x2A) = 0xF0;
  *(c.font + 0x2B) = 0x90;
  *(c.font + 0x2C) = 0xF0;

  *(c.font + 0x2D) = 0xF0;  // 9
  *(c.font + 0x2E) = 0x90;
  *(c.font + 0x2F) = 0xF0;
  *(c.font + 0x30) = 0x10;
  *(c.font + 0x31) = 0xF0;

  *(c.font + 0x32) = 0xF0;  // A
  *(c.font + 0x33) = 0x90;
  *(c.font + 0x34) = 0xF0;
  *(c.font + 0x35) = 0x90;
  *(c.font + 0x36) = 0x90;

  *(c.font + 0x37) = 0xE0;  // B
  *(c.font + 0x38) = 0x90;
  *(c.font + 0x39) = 0xE0;
  *(c.font + 0x3A) = 0x90;
  *(c.font + 0x3B) = 0xE0;

  *(c.font + 0x3C) = 0xF0;  // C
  *(c.font + 0x3D) = 0x80;
  *(c.font + 0x3E) = 0x80;
  *(c.font + 0x3F) = 0x80;
  *(c.font + 0x40) = 0xF0;

  *(c.font + 0x41) = 0xE0;  // D
  *(c.font + 0x42) = 0x90;
  *(c.font + 0x43) = 0x90;
  *(c.font + 0x44) = 0x90;
  *(c.font + 0x45) = 0xE0;

  *(c.font + 0x46) = 0xF0;  // E
  *(c.font + 0x47) = 0x80;
  *(c.font + 0x48) = 0xF0;
  *(c.font + 0x49) = 0x80;
  *(c.font + 0x4A) = 0xF0;

  *(c.font + 0x4B) = 0xF0;  // F
  *(c.font + 0x4C) = 0x80;
  *(c.font + 0x4D) = 0xF0;
  *(c.font + 0x4E) = 0x80;
  *(c.font + 0x4F) = 0x80;

  return c;
}

def dispose_context(c: *Context) {
  libc.free((*c).V);
  libc.free((*c).stack as *uint8);
  libc.free((*c).ram);
  libc.free((*c).font);
  libc.free((*c).framebuffer);
}

// Tick — Called per CPU tick
def tick(c: *Context) {
  // Decrement timers
  // TODO: Ensure timers are decremented at 60Hz
  if (*c).DT > 0 { (*c).DT -= 1; }
  if (*c).ST > 0 { (*c).ST -= 1; }
}
