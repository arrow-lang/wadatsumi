import "libc";
import "vec";

import "./cartridge";

struct MemoryController {
  Read: (*MemoryController, uint16, *uint8) -> bool;
  Write: (*MemoryController, uint16, uint8) -> bool;

  // Release (if `Data` is heap)
  Release: (*MemoryController) -> ();

  // 'self' instance that would otherwise be bound to those functions
  Data: *uint8;
}

struct MMU {
  /// Controllers (array)
  Controllers: vec.Vector<MemoryController>;

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
    m.Controllers = vec.Vector<MemoryController>.New();

    return m;
  }

  def Release(self) {
    // Release memory controllers
    let i = 0;
    while i < self.Controllers.size {
      // BUG(arrow): records must be assigned to variables before accessed right now
      let mc = self.Controllers.Get(i);
      mc.Release(&mc);
      i += 1;
    }

    // Free (_)RAM
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
    let value = 0xFF;

    // Check controllers
    let i = 0;
    while i < self.Controllers.size {
      // BUG(arrow): records must be assigned to variables before accessed right now
      let mc = self.Controllers.Get(i);
      if mc.Read(&mc, address, &value) {
        return value;
      }

      i += 1;
    }

    // TODO: Memory mappers should control that
    if address < 0x8000 {
      value = *(self.Cartridge.ROM + address);
    } else if address >= 0xC000 and address <= 0xFDFF {
      value = *(self.WRAM + (address & 0x1FFF));
    } else if address >= 0xFF80 and address <= 0xFFFE {
      value = *(self.HRAM + ((address & 0xFF) - 0x80));
    } else if address == 0xFF01 {
      // TODO: Move to a linkCable.as module
      value = self.SB;
    } else {
      // libc.printf("warn: read from unhandled memory: %04X\n", address);

      return 0xFF;
    }

    return value;
  }

  def Write(self, address: uint16, value: uint8) {
    // Check controllers
    let i = 0;
    while i < self.Controllers.size {
      // BUG(arrow): records must be assigned to variables before accessed right now
      let mc = self.Controllers.Get(i);
      if mc.Write(&mc, address, value) {
        return;
      }

      i += 1;
    }

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
