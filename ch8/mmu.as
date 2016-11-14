import "libc";

import "./machine";

def at(c: *machine.Context, address: uint16): *uint8 {
  if address < 0x200 {
    // Possible access into interpreter memory
    // Most accesses are illegal
    libc.printf("error: illegal access to interpreter memory at $%04X\n",
      address);

    libc.exit(1);
  }

  return ((*c).ram + ((address - 0x200) & 0xFFF));
}

def read(c: *machine.Context, address: uint16): uint8 {
  return *at(c, address);
}

def write(c: *machine.Context, address: uint16, value: uint8) {
  *at(c, address) = value;
}
