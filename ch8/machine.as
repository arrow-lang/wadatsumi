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

  libc.memset(c.framebuffer, 0, 64 * 32);

  // HACK: This should go elsewhere
  c.width = 64;
  c.height = 32;

  return c;
}

def dispose_context(c: *Context) {
  libc.free((*c).V);
  libc.free((*c).stack as *uint8);
  libc.free((*c).ram);
}

// Tick — Called per CPU tick
def tick(c: *Context) {
  // TODO: Timers
}
