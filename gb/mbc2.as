import "std";
import "libc";

import "./mmu";
import "./cartridge";

struct MBC2 {
  Cartridge: *cartridge.Cartridge;

  // Second ROM bank is specified here.
  // In range 1-16
  ROMBank: uint8;

  // RAM Enable
  // There is only 1 ram bank in MBC2
  RAMEnable: bool;
}

implement MBC2 {
  def Read(self, address: uint16, value: *uint8): bool {
    if address <= 0x3FFF {
      // ROM Bank $0
      *value = *(self.Cartridge.ROM + address);
    } else if address <= 0x7FFF {
      // ROM Bank $1 - $7F
      *value = *(self.Cartridge.ROM + (uint64(self.ROMBank) * 0x4000) + (uint64(address) - 0x4000));
    } else if address >= 0xA000 and address <= 0xBFFF {
      // RAM Bank $0 - $3
      let ramSize = self.Cartridge.ExternalRAMSize;
      let offset = uint64(address - 0xA000);
      if self.RAMEnable and offset < ramSize {
        *value = *(self.Cartridge.ExternalRAM + offset);
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
      // The least significant bit of the upper address byte must be '0' to
      // enable/disable cart RAM.
      if (address & 0x0100) == 0 {
        self.RAMEnable = (value & 0x0A) != 0;
      }
    } else if address <= 0x3FFF {
      // ROM Bank Number
      // The least significant bit of the upper address byte must be '1' to
      // select a ROM bank.
      if (address & 0x0100) != 0 {
        // Selecting $0 will bump you to $1
        self.ROMBank = (value & 0b1111);
        if self.ROMBank == 0 { self.ROMBank += 1; }
      }
    } else if address >= 0xA000 and address <= 0xBFFF {
      // External RAM
      let ramSize = self.Cartridge.ExternalRAMSize;
      let offset = uint64(address - 0xA000);
      if self.RAMEnable and offset < ramSize {
        *(self.Cartridge.ExternalRAM + offset) = value;
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
  mc.Data = libc.malloc(std.size_of<MBC2>()) as *uint8;
  mc.Release = MCRelease;

  let self_ = mc.Data as *MBC2;
  self_.Cartridge = cartridge_;
  self_.ROMBank = 0x01;
  self_.RAMEnable = false;

  return mc;
}

def MCRelease(this: *mmu.MemoryController) {
  let self_ = this.Data as *MBC2;
  libc.free(this.Data);
}

def MCRead(this: *mmu.MemoryController, address: uint16, value: *uint8): bool {
  return (this.Data as *MBC2).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *MBC2).Write(address, value);
}
