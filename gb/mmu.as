import "libc";
import "vec";

import "./cartridge";
import "./machine";

struct MemoryController {
  Read: (*MemoryController, uint16, *uint8) -> bool;
  Write: (*MemoryController, uint16, uint8) -> bool;

  // Release (if `Data` is heap)
  Release: (*MemoryController) -> ();

  // 'self' instance that would otherwise be bound to those functions
  Data: *uint8;
}

struct MMU {
  Machine: *machine.Machine;

  /// Controllers (array)
  Controllers: vec.Vector<MemoryController>;

  /// Cartridge (ROM)
  Cartridge: *cartridge.Cartridge;

  /// Work RAM (WRAM): C000-DFFF and E000-FDFF (8 KiB - 32 KiB)
  ///   Bank 0 is always available in memory at C000-CFFF,
  ///   Bank 1-7 can be selected into the address space at D000-DFFF.
  WRAM: *uint8;

  /// FF70 - SVBK - CGB Mode Only - WRAM Bank (0-7)
  SVBK: uint8;

  /// High RAM (HRAM): FF80-FFFE (127 B)
  HRAM: *uint8;

  /// Serial Transfer Data/Buffer (SB)
  // TODO: Move to a linkCable.as module
  SB: uint8;
}

implement MMU {
  def New(machine_: *machine.Machine, cart: *cartridge.Cartridge): Self {
    let m: Self;
    m.Machine = machine_;
    m.Cartridge = cart;
    m.WRAM = libc.malloc(0x8000);
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
    libc.memset(self.WRAM, 0, 0x8000);
    libc.memset(self.HRAM, 0, 127);

    // SVBK cannot be 0; so its first value is 1
    self.SVBK = 1;

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

    if address < 0x8000 {
      value = *(self.Cartridge.ROM + address);
    } else if address >= 0xC000 and address <= 0xFDFF {
      let offset = (address & 0x1FFF);
      if address > 0xCFFF {
        // Bank <1-7>
        offset += (uint16(self.SVBK - 1) * 0x1000);
      }

      value = *(self.WRAM + offset);
    } else if address == 0xFF70 and self.Machine.Mode == machine.MODE_CGB {
      value = (self.SVBK | 0b1111_1000);
    } else if address >= 0xFF80 and address <= 0xFFFE {
      value = *(self.HRAM + ((address & 0xFF) - 0x80));
    } else {
      libc.printf("warn: read from unhandled memory: %04X\n", address);
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
      let offset = (address & 0x1FFF);
      if address > 0xCFFF {
        // Bank <1-7>
        offset += (uint16(self.SVBK - 1) * 0x1000);
      }

      *(self.WRAM + offset) = value;
    } else if address == 0xFF70 and self.Machine.Mode == machine.MODE_CGB {
      self.SVBK = value & 0b111;
      if self.SVBK == 0 { self.SVBK += 1; }
    } else if address >= 0xFF80 and address <= 0xFFFE {
      *(self.HRAM + ((address & 0xFF) - 0x80)) = value;
    } else {
      libc.printf("warn: write to unhandled memory: %04X\n", address);
    }
  }
}
