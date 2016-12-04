
// Returns a value with the <n>th bit set or cleared (based on <value>)
// and all other bits (of an 8-bit number) cleared.
def Bit(value: bool, n: uint8): uint8 {
  return (1 if value else 0) << n;
}

// Returns the boolean value of the <n>th bit from <value>
def Test(value: uint8, n: uint8): bool {
  return (value & (1 << n)) != 0;
}
