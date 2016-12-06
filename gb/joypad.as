import "./cpu";
import "./mmu";
import "./machine";
import "./bits";

struct Joypad {
  CPU: *cpu.CPU;

  // Select
  Select_Button: bool;
  Select_Direction: bool;

  // State
  State_Start: bool;
  State_A: bool;
  State_B: bool;
  State_Select: bool;
  State_Up: bool;
  State_Down: bool;
  State_Left: bool;
  State_Right: bool;
}

implement Joypad {
  def New(cpu_: *cpu.CPU): Self {
    let j: Joypad;
    j.CPU = cpu_;

    return j;
  }

  def Reset(self, mode: machine.MachineMode) {
    // Input starts off disabled on CGB (but enabled on GB)
    self.Select_Button = (mode == machine.MODE_GB);
    self.Select_Direction = (mode == machine.MODE_GB);

    self.State_Start = false;
    self.State_A = false;
    self.State_B = false;
    self.State_Select = false;
    self.State_Up = false;
    self.State_Down = false;
    self.State_Left = false;
    self.State_Right = false;
  }

  def OnKey(self, which: uint32, isPressed: bool) {
    if which == 40 {
      // START => ENTER (US Keyboard)
      self.State_Start = isPressed;
    } else if which == 29 {
      // A => Z (US Keyboard)
      self.State_A = isPressed;
    } else if which == 27 {
      // B => X (US Keyboard)
      self.State_B = isPressed;
    } else if which == 225 {
      // SELECT => LEFT SHIFT (US Keyboard)
      self.State_Select = isPressed;
    } else if which == 82 {
      // UP => UP ARROW (US Keyboard)
      self.State_Up = isPressed;
    } else if which == 81 {
      // DOWN => DOWN ARROW (US Keyboard)
      self.State_Down = isPressed;
    } else if which == 80 {
      // LEFT => LEFT ARROW (US Keyboard)
      self.State_Left = isPressed;
    } else if which == 79 {
      // RIGHT => RIGHT ARROW (US Keyboard)
      self.State_Right = isPressed;
    }
  }

  def OnKeyPress(self, which: uint32) {
    self.OnKey(which, true);
  }

  def OnKeyRelease(self, which: uint32) {
    self.OnKey(which, false);
  }

  def Read(self, address: uint16, ptr: *uint8): bool {
    *ptr = if address == 0xFF00 {
      // P1 – Joypad (R/W)
      // Bit 7 - Not used
      // Bit 6 - Not used
      // Bit 5 - P15 Select Button Keys      (0=Select)
      // Bit 4 - P14 Select Direction Keys   (0=Select)
      // Bit 3 - P13 Input Down  or Start    (0=Pressed) (Read Only)
      // Bit 2 - P12 Input Up    or Select   (0=Pressed) (Read Only)
      // Bit 1 - P11 Input Left  or Button B (0=Pressed) (Read Only)
      // Bit 0 - P10 Input Right or Button A (0=Pressed) (Read Only)

      // NOTE: This is backwards logic to me. 0 = True ?
      (
        bits.Bit(true, 7) |
        bits.Bit(true, 6) |
        bits.Bit(not self.Select_Button, 5) |
        bits.Bit(not self.Select_Direction, 4) |
        bits.Bit(not ((self.Select_Button and self.State_Start) or (self.Select_Direction and self.State_Down)), 3) |
        bits.Bit(not ((self.Select_Button and self.State_Select) or (self.Select_Direction and self.State_Up)), 2) |
        bits.Bit(not ((self.Select_Button and self.State_B) or (self.Select_Direction and self.State_Left)), 1) |
        bits.Bit(not ((self.Select_Button and self.State_A) or (self.Select_Direction and self.State_Right)), 0)
      );
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if address == 0xFF00 {
      self.Select_Button = not bits.Test(value, 5);
      self.Select_Direction = not bits.Test(value, 4);
    } else {
      return false;
    }

    return true;
  }

  def AsMemoryController(self, this: *Joypad): mmu.MemoryController {
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
  return (this.Data as *Joypad).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *Joypad).Write(address, value);
}
