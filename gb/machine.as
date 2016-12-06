import "libc";

import "./cpu";
import "./gpu";
import "./apu";
import "./mmu";
import "./cartridge";
import "./joypad";
import "./timer";
import "./linkCable";

import "./mbc1";
import "./mbc2";
import "./mbc3";
import "./mbc5";

struct Machine {
  CPU: cpu.CPU;
  GPU: gpu.GPU;
  APU: apu.APU;
  MMU: mmu.MMU;
  Joypad: joypad.Joypad;
  Timer: timer.Timer;
  Cartridge: cartridge.Cartridge;
  LinkCable: linkCable.LinkCable;
}

implement Machine {
  def New(): Self {
    let m: Machine;

    return m;
  }

  // HACK: Taking the address of a reference (`self`) dies
  def Acquire(self, this: *Machine) {
    self.Cartridge = cartridge.Cartridge.New();

    self.MMU = mmu.MMU.New(&self.Cartridge);

    self.CPU = cpu.CPU.New(this, &self.MMU);
    self.CPU.Acquire();

    self.GPU = gpu.GPU.New(&self.CPU);

    self.APU = apu.APU.New();

    self.Timer = timer.Timer.New(&self.CPU);

    self.Joypad = joypad.Joypad.New(&self.CPU);

    self.LinkCable = linkCable.LinkCable.New();

    // BUG(Arrow) -- records need to be assigned before use
    let mc = self.CPU.AsMemoryController(&self.CPU);
    self.MMU.Controllers.Push(mc);

    mc = self.GPU.AsMemoryController(&self.GPU);
    self.MMU.Controllers.Push(mc);

    mc = self.APU.AsMemoryController(&self.APU);
    self.MMU.Controllers.Push(mc);

    mc = self.Timer.AsMemoryController(&self.Timer);
    self.MMU.Controllers.Push(mc);

    mc = self.Joypad.AsMemoryController(&self.Joypad);
    self.MMU.Controllers.Push(mc);

    mc = self.LinkCable.AsMemoryController(&self.LinkCable);
    self.MMU.Controllers.Push(mc);
  }

  def Release(self) {
    self.CPU.Release();
    self.GPU.Release();
    self.APU.Release();
    self.MMU.Release();
    self.Cartridge.Release();
  }

  def Open(self, filename: str) {
    self.Cartridge.Open(filename);
    self.Cartridge.Trace();

    if self.Cartridge.MC != 0 {
      // Push cartridge memory controller
      let mc: mmu.MemoryController;
      if self.Cartridge.MC == cartridge.MBC1 {
        mc = mbc1.New(&self.Cartridge);
      } else if self.Cartridge.MC == cartridge.MBC2 {
        mc = mbc2.New(&self.Cartridge);
      } else if self.Cartridge.MC == cartridge.MBC3 {
        mc = mbc3.New(&self.Cartridge);
      } else if self.Cartridge.MC == cartridge.MBC5 {
        mc = mbc5.New(&self.Cartridge);
      } else {
        libc.printf("error: unsupported cartridge type: %02X\n",
          self.Cartridge.Type);

        libc.exit(-1);
      }

      if self.Cartridge.HasTimer {
        libc.printf("error: unsupported cartridge type: %02X\n",
          self.Cartridge.Type);

        libc.exit(-1);
      }

      self.MMU.Controllers.Push(mc);
    }
  }

  def Reset(self) {
    self.Timer.Reset();
    self.CPU.Reset();
    self.GPU.Reset();
    self.Joypad.Reset();
    self.LinkCable.Reset();
    self.MMU.Reset();
  }

  def Run(self) {
    self.CPU.Run(&self.CPU, 100);
  }

  def Tick(self) {
    self.Timer.Tick();
    self.GPU.Tick();
    self.APU.Tick();
    // self.LinkCable.Tick();
  }

  def SetOnRefresh(self, fn: (*gpu.Frame) -> ()) {
    self.GPU.SetOnRefresh(fn);
  }

  def OnKeyPress(self, which: uint32) {
    self.Joypad.OnKeyPress(which);
  }

  def OnKeyRelease(self, which: uint32) {
    self.Joypad.OnKeyRelease(which);
  }
}
