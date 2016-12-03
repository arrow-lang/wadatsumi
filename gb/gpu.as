import "libc";

import "./cpu";
import "./mmu";

struct GPU {
  CPU: *cpu.CPU;

  // Video RAM — 8 KiB
  VRAM: *uint8;

  // Cycle counter for Mode
  Cycles: uint16;

  // Scanline — current line being rendered
  Scanline: uint16;

  // Mode — 0/1/2/3
  //   0: H-Blank
  //   1: V-Blank
  //   2: Searching OAM-RAM
  //   3: Transferring Data to LCD Driver.
  Mode: uint8;
}

implement GPU {
  def New(cpu_: *cpu.CPU): Self {
    let g: GPU;
    g.CPU = cpu_;
    g.VRAM = libc.malloc(0x2000);

    return g;
  }

  def Release(self) {
    libc.free(self.VRAM);
  }

  def Reset(self) {
    libc.memset(self.VRAM, 0, 0x2000);

    self.Scanline = 0;
    self.Mode = 0;
    self.Cycles = 0;
  }

  def Render(self) {
    // [....]
  }

  def RenderBackground(self) {
    // [....]
  }

  /*
  The STAT IRQ is triggered by an internal signal

  This signal is set to 1 if:
   ( (LY = LYC) AND (STAT.ENABLE_LYC_COMPARE = 1) ) OR
   ( (ScreenMode = 0) AND (STAT.ENABLE_HBL = 1) ) OR
   ( (ScreenMode = 2) AND (STAT.ENABLE_OAM = 1) ) OR
   ( (ScreenMode = 1) AND (STAT.ENABLE_VBL || STAT.ENABLE_OAM) ) -> Not only

  The interrupt is fired when the signal TRANSITIONS from 0 TO 1
  If it STAYS 1 during a screen mode change then no interrupt is fired.
  */

  def Tick(self) {
    // TODO: STAT Interrupt (from signal)
    self.Cycles += 1;
    if self.Mode == 0 and self.Cycles <= 1 {
      // Each scanline (outside of VBLK) is in mode 0 for 1 cycle
      if self.Scanline <= 143 {
        self.Mode = 2;
      } else {
        // Enter V-Blank
        self.Mode = 1;
        self.CPU.IF |= 0x01;
      };
    } else if self.Mode == 2 and self.Cycles >= (84 / 4) {
      // Mode 2 lasts for 84 clocks
      self.Mode = 3;
    } else if self.Mode == 3 and self.Cycles >= (256 / 4) {
      // TODO: https://www.reddit.com/r/EmuDev/comments/59pawp/gb_mode3_sprite_timing/?st=iw9j5tnl&sh=6825f812
      //       Need to determine proper length of mode-3
      self.Mode = 0;

      // Render: Scanline
      self.Render();
    } else if self.Mode == 0 and self.Cycles >= (452 / 4) {
      // Each scanline lasts for exactly 452 clocks
      self.Scanline += 1;
      self.Mode = 0;
      self.Cycles -= (452 / 4);
    } else if self.Mode == 1 {
      if self.Cycles >= (452 / 4) {
        // Each scanline in VBLANK lasts for the same 452 clocks
        // Mode 1 is persisted until line-153
        if self.Scanline == 0 {
          self.Mode = 0;
        } else {
          self.Scanline += 1;
        }
        self.Cycles -= (452 / 4);
      } else if self.Scanline >= 153 and self.Cycles >= 1 {
        // Scanline counter is reset to 0 on the first cycle of #153
        self.Scanline = 0;
      }
    }
  }

  def Read(self, address: uint16, value: *uint8): bool {
    return false;
  }

  def Write(self, address: uint16, value: uint8): bool {
    return false;
  }

    def AsMemoryController(self, this: *GPU): mmu.MemoryController {
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
    return (this.Data as *GPU).Read(address, value);
  }

  def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
    return (this.Data as *GPU).Write(address, value);
  }
