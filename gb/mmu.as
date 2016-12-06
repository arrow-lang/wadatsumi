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

    // Reset a ton of cross-component registers to DMG initial values
    self.Write(0xFF05, 0x00);
    self.Write(0xFF06, 0x00);
    self.Write(0xFF07, 0x00);
    self.Write(0xFF10, 0x80);
    self.Write(0xFF11, 0xBF);
    self.Write(0xFF12, 0xF3);
    self.Write(0xFF16, 0x3F);
    self.Write(0xFF17, 0x00);
    self.Write(0xFF1A, 0x7F);
    self.Write(0xFF1B, 0xFF);
    self.Write(0xFF1C, 0x9F);
    self.Write(0xFF20, 0xFF);
    self.Write(0xFF21, 0x00);
    self.Write(0xFF22, 0x00);
    self.Write(0xFF24, 0x77);
    self.Write(0xFF25, 0xF3);
    self.Write(0xFF26, 0xF1);
    self.Write(0xFF40, 0x91);
    self.Write(0xFF42, 0x00);
    self.Write(0xFF43, 0x00);
    self.Write(0xFF45, 0x00);
    self.Write(0xFF47, 0xFC);
    self.Write(0xFF48, 0xFF);
    self.Write(0xFF49, 0xFF);
    self.Write(0xFF4A, 0x00);
    self.Write(0xFF4B, 0x00);
    self.Write(0xFFFF, 0x00);
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
    } else {
      // libc.printf("warn: write to unhandled memory: %04X\n", address);
    }
  }
}
