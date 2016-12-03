import "libc";

import "./cpu";
import "./gpu";
import "./mmu";
import "./cartridge";
import "./timer";

import "./mbc1";

struct Machine {
  CPU: cpu.CPU;
  GPU: gpu.GPU;
  MMU: mmu.MMU;
  Timer: timer.Timer;
  Cartridge: cartridge.Cartridge;
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

    self.Timer = timer.Timer.New();

    self.CPU = cpu.CPU.New(this, &self.MMU);
    self.CPU.Acquire();

    self.GPU = gpu.GPU.New(&self.CPU);

    self.Timer.Acquire(&self.CPU);

    // BUG(Arrow) -- records need to be assigned before use
    let mc = self.CPU.AsMemoryController(&self.CPU);
    self.MMU.Controllers.Push(mc);

    mc = self.GPU.AsMemoryController(&self.GPU);
    self.MMU.Controllers.Push(mc);

    mc = self.Timer.AsMemoryController(&self.Timer);
    self.MMU.Controllers.Push(mc);

    mc = self.GPU.AsMemoryController(&self.GPU);
    self.MMU.Controllers.Push(mc);
  }

  def Release(self) {
    self.CPU.Release();
    self.GPU.Release();
    self.MMU.Release();
    self.Cartridge.Release();
  }

  def Open(self, filename: str) {
    self.Cartridge.Open(filename);

    if self.Cartridge.MC != 0 {
      // Push cartridge memory controller
      let mc: mmu.MemoryController;
      if self.Cartridge.MC == cartridge.MBC1 {
        mc = mbc1.New(&self.Cartridge);
      } else {
        libc.printf("error: unsupported cartridge type: %02X\n",
          self.Cartridge.Type);

        libc.exit(-1);
      }

      self.MMU.Controllers.Push(mc);
    }
  }

  def Reset(self) {
    self.MMU.Reset();
    self.Timer.Reset();
    self.CPU.Reset();
    self.GPU.Reset();
  }

  def Run(self) {
    self.CPU.Run(&self.CPU, 100);
  }

  def Tick(self) {
    self.Timer.Tick();
    self.GPU.Tick();
  }
}
