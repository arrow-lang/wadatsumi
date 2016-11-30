import "libc";

import "./cpu";
import "./mmu";
import "./cartridge";

struct Machine {
  CPU: cpu.CPU;
  MMU: mmu.MMU;
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

    self.CPU = cpu.CPU.New(this, &self.MMU);
    self.CPU.Acquire();
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
    self.CPU.Reset();
    self.MMU.Reset();
  }

  def Run(self) {
    self.CPU.Run(&self.CPU, 5);
  }

  def Tick(self) {
    // ...
  }
}
