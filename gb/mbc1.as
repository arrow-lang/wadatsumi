import "std";
import "libc";

import "./mmu";
import "./cartridge";

struct MBC1 {
  Cartridge: *cartridge.Cartridge;

  // Second ROM bank is specified here.
  // In range 1-127
  // Banks $20, $40, and $60 are seen as $21, $41, and $61.
  ROMBank: uint8;

  // In range 0-3
  RAMBank: uint8;
  RAMEnable: bool;

  // Mode (ROM / RAM)
  Mode: uint8;

  // External RAM
  ERAM: *uint8;
}

implement MBC1 {
  def Read(self, address: uint16, value: *uint8): bool {
    if address <= 0x3FFF {
      // ROM Bank $0
      *value = *(self.Cartridge.ROM + address);
    } else if address <= 0x7FFF {
      // ROM Bank $1 - $7F
      *value = *(self.Cartridge.ROM + (uint64(self.ROMBank) * 0x4000) + (uint64(address) - 0x4000));
    } else if address >= 0xA000 and address <= 0xBFFF {
      // RAM Bank $0 - $3
      let ramSize = self.Cartridge.RAMSize * 1024;
      let offset = uint32(address - 0xA000);
      if self.RAMEnable and offset < ramSize {
        *value = *((self.ERAM + (uint64(self.RAMBank) * 0x2000)) + offset);
      } else {
        // External RAM is not enabled
        *value = 0xFF;
      }
    } else {
      return false;
    }

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if address <= 0x1FFF {
      // RAM Enable
      self.RAMEnable = (value & 0x0A) != 0;
    } else if address <= 0x3FFF {
      // ROM Bank Number (lower 5 bits)
      self.ROMBank &= ~0x1F;
      self.ROMBank |= (value & 0x1F);

      // Selecting an invalid bank will bump you up a bank
      let n = (self.ROMBank & 0x1F);
      if n == 0x20 or n == 0x40 or n == 0x60 or n == 0x00 {
        self.ROMBank += 1;
      }
    } else if address <= 0x5FFF {
      // RAM Bank Number OR Upper 2 bits of ROM Bank Number
      if self.Mode == 0x00 {
        self.RAMBank = value & 0x3;
      } else if self.Mode == 0x01 {
        self.ROMBank &= ~0x60;
        self.ROMBank |= (value & 0x3) << 5;
      }
    } else if address <= 0x7FFF {
      // ROM/RAM Mode Select
      let mode = value & 0x1;
      if mode != self.Mode {
        if mode == 0x00 {
          let tmp = (self.ROMBank & 0x60) >> 5;
          self.ROMBank &= ~0x60;
          self.RAMBank = tmp;
        } else if mode == 0x01 {
          let tmp = self.RAMBank;
          self.RAMBank = 0x00;
          self.ROMBank &= ~0x60;
          self.ROMBank |= (tmp & 0x3) << 5;
        }
      }
    } else if address >= 0xA000 and address <= 0xBFFF {
      // External RAM
      let ramSize = self.Cartridge.RAMSize * 1024;
      let offset = uint32(address - 0xA000);
      if self.RAMEnable and offset < ramSize {
        *((self.ERAM + (uint64(self.RAMBank) * 0x2000)) + offset) = value;
      }
    } else {
      // Unhandled
      return false;
    }

    return true;
  }
}

def New(cartridge_: *cartridge.Cartridge): mmu.MemoryController {
  let mc: mmu.MemoryController;
  mc.Read = MCRead;
  mc.Write = MCWrite;
  mc.Data = libc.malloc(std.size_of<MBC1>()) as *uint8;
  mc.Release = MCRelease;

  let self_ = mc.Data as *MBC1;
  self_.Cartridge = cartridge_;
  self_.ERAM = libc.malloc(uint64(self_.Cartridge.RAMSize * 1024));
  self_.ROMBank = 0x01;
  self_.RAMBank = 0x00;
  self_.RAMEnable = false;
  self_.Mode = 0x00;

  return mc;
}

def MCRelease(this: *mmu.MemoryController) {
  let self_ = this.Data as *MBC1;
  libc.free(self_.ERAM);
  libc.free(this.Data);
}

def MCRead(this: *mmu.MemoryController, address: uint16, value: *uint8): bool {
  return (this.Data as *MBC1).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *MBC1).Write(address, value);
}
