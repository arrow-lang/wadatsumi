import "libc";

import "./cartridge";

struct MMU {
  /// Cartridge (ROM)
  Cartridge: *cartridge.Cartridge;

  /// Work RAM (WRAM): C000-DFFF and E000-FDFF (8 KiB)
  WRAM: *uint8;

  /// High RAM (HRAM): FF80-FFFE (127 B)
  HRAM: *uint8;

  /// Serial Transfer Data/Buffer (SB)
  // TODO: Move to a linkCable.as module
  SB: uint8;
}

implement MMU {
  def New(cart: *cartridge.Cartridge): Self {
    let m: Self;
    m.Cartridge = cart;
    m.WRAM = libc.malloc(0x2000);
    m.HRAM = libc.malloc(127);

    return m;
  }

  def Release(self) {
    libc.free(self.WRAM);
    libc.free(self.HRAM);
  }

  def Reset(self) {
    libc.memset(self.WRAM, 0, 0x2000);
    libc.memset(self.HRAM, 0, 127);

    // TODO: Move to a linkCable.as module
    self.SB = 0;
  }

  def Read(self, address: uint16): uint8 {
    // TODO: Memory mappers should control that
    if address < 0x8000 {
      return *(self.Cartridge.ROM + address);
    }

    if address >= 0xC000 and address <= 0xFDFF {
      return *(self.WRAM + (address & 0x1FFF));
    }

    if address >= 0xFF80 and address <= 0xFFFE {
      return *(self.HRAM + ((address & 0xFF) - 0x80));
    }

    // TODO: Move to a linkCable.as module
    if address == 0xFF01 {
      return self.SB;
    }

    // libc.printf("warn: read from unhandled memory: %04X\n", address);

    return 0xFF;
  }

  def Write(self, address: uint16, value: uint8) {
    if address >= 0xC000 and address <= 0xFDFF {
      *(self.WRAM + (address & 0x1FFF)) = value;
    } else if address >= 0xFF80 and address <= 0xFFFE {
      *(self.HRAM + ((address & 0xFF) - 0x80)) = value;
    } else if address == 0xFF01 {
      // TODO: Move to a linkCable.as module
      self.SB = value;
    } else if address == 0xFF02 {
      // TODO: Move to a linkCable.as module
      if value & 0x80 != 0 {
        libc.printf("%c", self.SB);
      }
    } else {
      // libc.printf("warn: write to unhandled memory: %04X\n", address);
    }
  }
}
