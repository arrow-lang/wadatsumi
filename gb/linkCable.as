import "./bits";
import "./mmu";

// TODO(wadatsumi): Just the barest bare bones here

struct LinkCable {
  // FF01 – SB - Serial Transfer Data/Buffer (R/W)
  SB: uint8;

  // FF02 – SC – Serial Transfer Control (R/W)
  //   Bit 7 - Transfer Start Flag (0=No Transfer, 1=Start)
  //   Bit 0 - Shift Clock (0=External Clock, 1=Internal Clock)
  ShiftClock: bool;
}

implement LinkCable {
  def New(): Self {
    let component: LinkCable;
    return component;
  }

  def Reset(self) {
    self.SB = 0x0;
    self.ShiftClock = false;
  }

  def Read(self, address: uint16, ptr: *uint8): bool {
    *ptr = if address == 0xFF01 {
      self.SB;
    } else if address == 0xFF02 {
      (
        bits.Bit(false, 7) |
        bits.Bit(true, 6) |
        bits.Bit(true, 5) |
        bits.Bit(true, 4) |
        bits.Bit(true, 3) |
        bits.Bit(true, 2) |
        bits.Bit(true, 1) |
        bits.Bit(self.ShiftClock, 0)
      );
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if address == 0xFF01 {
      self.SB = value;
    } else if address == 0xFF02 {
      self.ShiftClock = bits.Test(value, 0);
    } else {
      return false;
    }

    return true;
  }

  def AsMemoryController(self, this: *LinkCable): mmu.MemoryController {
    let mc: mmu.MemoryController;
    mc.Read = MCRead;
    mc.Write = MCWrite;
    mc.Data = this as *uint8;
    mc.Release = MCRelease;

    return mc;
  }
}

def MCRelease(this: *mmu.MemoryController) {
  // Do nothing
}

def MCRead(this: *mmu.MemoryController, address: uint16, value: *uint8): bool {
  return (this.Data as *LinkCable).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *LinkCable).Write(address, value);
}
