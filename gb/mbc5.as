import "std";
import "libc";

import "./mmu";
import "./cartridge";

// TODO(wadatsumi): RTC
// TODO(wadatsumi): Rumble

struct MBC3 {
  Cartridge: *cartridge.Cartridge;

  // Second ROM bank is specified here.
  // In range $0 - $1E0
  ROMBank: uint16;

  // Ext. RAM BANK
  // In range $0 - $F
  RAMBank: uint8;

  // Ext. RAM Enable
  RAMEnable: bool;
}

implement MBC3 {
  def Read(self, address: uint16, value: *uint8): bool {
    if address <= 0x3FFF {
      // ROM Bank $0
      *value = *(self.Cartridge.ROM + address);
    } else if address <= 0x7FFF {
      // ROM Bank $0 - $1E0
      *value = *(self.Cartridge.ROM + (uint64(self.ROMBank) * 0x4000) + (uint64(address) - 0x4000));
    } else if address >= 0xA000 and address <= 0xBFFF {
      // RAM Bank $0 - $F
      let ramSize = self.Cartridge.ExternalRAMSize;
      let offset = uint64(address - 0xA000);
      if self.RAMEnable and offset < ramSize {
        *value = *((self.Cartridge.ExternalRAM + (uint64(self.RAMBank) * 0x2000)) + offset);
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
    } else if address <= 0x2FFF {
      // ROM Bank Number — lower 8-bits
      self.ROMBank &= ~0xFF;
      self.ROMBank |= uint16(value);
    } else if address <= 0x3FFF {
      // ROM Bank Number — upper 8-bits
      self.ROMBank &= ~0xFF00;
      self.ROMBank |= (uint16(value) << 8);
    } else if address <= 0x5FFF {
      // RAM Bank Number
      self.RAMBank = value & 0xF;

      // Rumble ON/OFF
      // In cartridges with rumble, writing a '1' to bit 4 will enable the
      // electric motor, writing a '0' will disable it
      // TODO: Do something with this
      // let rumbleOn = value & 0b10000;
    } else if address >= 0xA000 and address <= 0xBFFF {
      // External RAM
      let ramSize = self.Cartridge.ExternalRAMSize;
      let offset = uint64(address - 0xA000);
      if self.RAMEnable and offset < ramSize {
        *((self.Cartridge.ExternalRAM + (uint64(self.RAMBank) * 0x2000)) + offset) = value;
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
  mc.Data = libc.malloc(std.size_of<MBC3>()) as *uint8;
  mc.Release = MCRelease;

  let self_ = mc.Data as *MBC3;
  self_.Cartridge = cartridge_;
  self_.ROMBank = 0x01;
  self_.RAMBank = 0x00;
  self_.RAMEnable = false;

  return mc;
}

def MCRelease(this: *mmu.MemoryController) {
  let self_ = this.Data as *MBC3;
  libc.free(this.Data);
}

def MCRead(this: *mmu.MemoryController, address: uint16, value: *uint8): bool {
  return (this.Data as *MBC3).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *MBC3).Write(address, value);
}
