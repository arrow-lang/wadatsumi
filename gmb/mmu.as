import "libc";

import "./cartridge";
import "./cpu";
import "./timer";

struct MMU {
  /// Components (that have Memory contorl)
  CPU: *cpu.CPU;
  Timer: *timer.Timer;

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

  def Acquire(self, cpu_: *cpu.CPU, timer_: *timer.Timer) {
    self.CPU = cpu_;
    self.Timer = timer_;
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
    let value = 0xFF;

    // Check handlers
    // TODO: When we have closures we can make this an array
    if self.CPU.Read(address, &value) { return value; }
    if self.Timer.Read(address, &value) { return value; }
    // if self.GPU.Read(address, &value) { return value; }

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
    // Check handlers
    // TODO: When we have closures we can make this an array
    if self.CPU.Write(address, value) { return; }
    if self.Timer.Write(address, value) { return; }
    // if self.GPU.Write(address, value) { return; }

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
