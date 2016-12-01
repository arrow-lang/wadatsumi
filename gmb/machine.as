import "libc";

import "./cpu";
import "./mmu";
import "./cartridge";
import "./timer";

struct Machine {
  CPU: cpu.CPU;
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

    self.Timer.Acquire(&self.CPU);

    // BUG(Arrow) -- records need to be assigned before use
    let mc = self.CPU.AsMemoryController(&self.CPU);
    self.MMU.Controllers.Push(mc);

    mc = self.Timer.AsMemoryController(&self.Timer);
    self.MMU.Controllers.Push(mc);

    // self.MMU.Controllers.Push(self.GPU.AsMemoryController(&self.GPU));
  }

  def Release(self) {
    self.CPU.Release();
    self.MMU.Release();
    self.Cartridge.Release();
  }

  def Open(self, filename: str) {
    self.Cartridge.Open(filename);
  }

  def Reset(self) {
    self.MMU.Reset();
    self.Timer.Reset();
    self.CPU.Reset();
  }

  def Run(self) {
    self.CPU.Run(&self.CPU, 5);
  }

  def Tick(self) {
    self.Timer.Tick();
  }
}
