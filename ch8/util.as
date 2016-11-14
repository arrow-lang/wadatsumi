
// Get 16-bit value from 8-bit address (to a 16-bit value)
def get16(address: *uint8): uint16 {
  let h = *address;
  let l = *(address + 1);

  return (uint16(h) << 8) | uint16(l);
}

// Get 12-bit value from 8-bit address (to a 16-bit value)
def get12(address: *uint8): uint16 {
  let h = *address;
  let l = *(address + 1);

  return (uint16((h & 0x0F)) << 8) | uint16(l);
}

// Get 8-bit value from 8-bit address (to a 16-bit value)
// Indices number from right-to-left (starting at 0)
def get8(address: *uint8, index: uint8): uint8 {
  return *(address + (1 - index));
}

// Get 4-bit value from 4-bit address (to a 16-bit value)
// Indices number from right-to-left (starting at 0)
def get4(address: *uint8, index: uint8): uint8 {
  let offset = if (index & 0x2) != 0 { 0; } else { 1; };
  let value = *(address + offset);

  return (value >> ((index & 0x1) << 2)) & 0xF;
}
