import "std";
import "libc";

import "./mmu";
import "./cartridge";

// TODO(wadatsumi): RTC

struct MBC3 {
  Cartridge: *cartridge.Cartridge;

  // Second ROM bank is specified here.
  // In range 1-127
  ROMBank: uint8;

  // In range 0-3 for RAM and 08h-0Ch for RTC
  RAMBankOrTimerRegister: uint8;
  RAMAndTimerEnable: bool;
}

implement MBC3 {
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
      if self.RAMAndTimerEnable and offset < ramSize {
        *value = *((self.Cartridge.ExternalRAM + (uint64(self.RAMBankOrTimerRegister) * 0x2000)) + offset);
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
      self.RAMAndTimerEnable = (value & 0x0A) != 0;
    } else if address <= 0x3FFF {
      // ROM Bank Number
      // Selecting $0 will bump you to $1
      self.ROMBank = value;
      if self.ROMBank == 0 { self.ROMBank += 1; }
    } else if address <= 0x5FFF {
      // RAM Bank Number OR RTC Select
      self.RAMBankOrTimerRegister = value;
    } else if address <= 0x7FFF {
      // TODO: Latch Clock Data
    } else if address >= 0xA000 and address <= 0xBFFF {
      // External RAM
      let ramSize = self.Cartridge.ExternalRAMSize;
      let offset = uint64(address - 0xA000);
      if self.RAMAndTimerEnable and offset < ramSize {
        *((self.Cartridge.ExternalRAM + (uint64(self.RAMBankOrTimerRegister) * 0x2000)) + offset) = value;
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
  self_.RAMBankOrTimerRegister = 0x00;
  self_.RAMAndTimerEnable = false;

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
