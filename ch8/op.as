import "libc";

import "./machine";
import "./util";
import "./mmu";

/// An opcode in CHIP-8 is composed of an instruction (group) identifier,
/// and (up to) 3 8-bit operands. An operand may be repuroposed into a second
/// part of the instruction identifier. An instruction may use all 3 8-bit
/// operands as a single 12-bit operand.
///
/// Most CHIP-8 reference documents describe the operands as `XYN`. Following
/// that, `.x()`, `.y()`, and `.n()` access the 3 8-bit operands.
/// The single 12-bit operand is accessed via `.address()`.
/// The insturction identifier is accessed via `.i()`.
/// The second 2 8-bit operands can be accessed via `.data()`.
struct Opcode { _address: *uint8 }
implement Opcode {
  def new(address: *uint8): Opcode {
    let result: Opcode;
    result._address = address;

    return result;
  }

  def at(self, index: uint8): uint8 {
    let offset = if (index & 0x2) != 0 { 0; } else { 1; };
    let value = *(self._address + offset);

    return (value >> ((index & 0x1) << 2)) & 0xF;
  }

  // @property (?)
  def address(self): uint16 {
    let h = *(self._address + 0);
    let l = *(self._address + 1);

    return (uint16((h & 0x0F)) << 8) | uint16(l);
  }

  // @property (?)
  def i(self): uint8 {
    return self.at(3);
  }

  // @property (?)
  def x(self): uint8 {
    return self.at(2);
  }

  // @property (?)
  def y(self): uint8 {
    return self.at(1);
  }

  // @property (?)
  def n(self): uint8 {
    return self.at(0);
  }

  // @property (?)
  def data(self): uint8 {
    return self.at(0) | (self.at(1) << 4);
  }
}

def execute(c: *machine.Context, address: *uint8) {
  let opcode = Opcode.new(address);
  let refresh = false;

  // libc.printf("[%04X] %04X\n", c.PC, oc);

  // TODO: HashMap for operations might make this look nicer

  if opcode.i() == 0x0 and opcode.address() == 0x0E0 {
    _00E0(c, opcode);
  } else if opcode.i() == 0x0 and opcode.address() == 0x0EE {
    _00EE(c, opcode);
  } else if opcode.i() == 0x0 and opcode.address() == 0x230 {
    _0230(c, opcode);
  } else if opcode.i() == 0x0 {
    _0nnn(c, opcode);
  } else if opcode.i() == 0x1 {
    _1nnn(c, opcode);
  } else if opcode.i() == 0x2 {
    _2nnn(c, opcode);
  } else if opcode.i() == 0x3 {
    _3xkk(c, opcode);
  } else if opcode.i() == 0x4 {
    _4xkk(c, opcode);
  } else if opcode.i() == 0x5 {
    _5xy0(c, opcode);
  } else if opcode.i() == 0x6 {
    _6xkk(c, opcode);
  } else if opcode.i() == 0x7 {
    _7xkk(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0x0 {
    _8xy0(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0x1 {
    _8xy1(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0x2 {
    _8xy2(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0x3 {
    _8xy3(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0x4 {
    _8xy4(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0x5 {
    _8xy5(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0x6 {
    _8xy6(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0x7 {
    _8xy7(c, opcode);
  } else if opcode.i() == 0x8 and opcode.n() == 0xE {
    _8xyE(c, opcode);
  } else if opcode.i() == 0x9 {
    _9xy0(c, opcode);
  } else if opcode.i() == 0xA {
    _Annn(c, opcode);
  } else if opcode.i() == 0xB {
    _Bnnn(c, opcode);
  } else if opcode.i() == 0xC {
    _Cxkk(c, opcode);
  } else if opcode.i() == 0xD {
    _Dxyn(c, opcode);
    refresh = true;
  } else if opcode.i() == 0xE and opcode.data() == 0x9E {
    _Ex9E(c, opcode);
  } else if opcode.i() == 0xE and opcode.data() == 0xA1 {
    _ExA1(c, opcode);
  } else if opcode.i() == 0xF and opcode.data() == 0x07 {
    _Fx07(c, opcode);
  } else if opcode.i() == 0xF and opcode.data() == 0x15 {
    _Fx15(c, opcode);
  } else if opcode.i() == 0xF and opcode.data() == 0x18 {
    _Fx18(c, opcode);
  } else if opcode.i() == 0xF and opcode.data() == 0x1E {
    _Fx1E(c, opcode);
  } else if opcode.i() == 0xF and opcode.data() == 0x29 {
    _Fx29(c, opcode);
  } else if opcode.i() == 0xF and opcode.data() == 0x33 {
    _Fx33(c, opcode);
  } else if opcode.i() == 0xF and opcode.data() == 0x55 {
    _Fx55(c, opcode);
  } else if opcode.i() == 0xF and opcode.data() == 0x65 {
    _Fx65(c, opcode);
  } else {
    _unknown(address);
  }

  if refresh {
    machine.refresh(c);
  }
}

// Unknown opcode
def _unknown(opcode: *uint8) {
  libc.printf("error: unknown opcode: $%02X%02X\n",
    *(opcode),
    *(opcode + 1),
  );

  libc.exit(1);
}

// SYS
def _0nnn(c: *machine.Context, opcode: Opcode) {
  // Jump to a machine code routine at nnn.
  // NOTE: Ignore
}

// CLS
def _00E0(c: *machine.Context, opcode: Opcode) {
  // Clear the Chip-8 64x32 display.
  // NOTE: Still clear this size screen, even when in High-Res mode.
  libc.memset(c.framebuffer, 0, 32 * 64);
}

// HRCLS
def _0230(c: *machine.Context, opcode: Opcode) {
  // Clear the High-Res Chip-8 64x64 display.
  // NOTE: In normal-res mode this is identical to $00E0
  libc.memset(c.framebuffer, 0, 64 * 64);
}

// RET
def _00EE(c: *machine.Context, opcode: Opcode) {
  // Return from a subroutine.
  // NOTE: The stack is only 16 "slots"
  c.SP = if c.SP == 0 { 0xF; } else { c.SP - 1; };
  c.PC = *(c.stack + c.SP);
}

// JP nnn
def _1nnn(c: *machine.Context, opcode: Opcode) {
  // Jump to address
  c.PC = opcode.address();
}

// CALL nnn
def _2nnn(c: *machine.Context, opcode: Opcode) {
  // Call subroutine.

  // Push PC on top of the stack.
  *(c.stack + c.SP) = c.PC;

  // Increment the stack pointer (for the push)
  // NOTE: The stack wraps around its 16-slot area
  c.SP += 1;
  if c.SP >= 0x10 { c.SP = 0; }

  // Set PC to address
  c.PC = opcode.address();
}

// SE Vx, kk
def _3xkk(c: *machine.Context, opcode: Opcode) {
  // Skip next instruction if Vx == kk
  if *(c.V + opcode.x()) == opcode.data() {
    c.PC += 2;
  }
}

// SNE Vx, kk
def _4xkk(c: *machine.Context, opcode: Opcode) {
  // Skip next instruction if Vx != kk
  if *(c.V + opcode.x()) != opcode.data() {
    c.PC += 2;
  }
}

// SE Vx, Vy
def _5xy0(c: *machine.Context, opcode: Opcode) {
  // Skip next instruction if Vx = Vy

  // if c.V[X(opcode)] == c.V[Y(opcode)] {
  //   c.PC += 2;
  // }

  if *(c.V + opcode.x()) == *(c.V + opcode.y()) {
    c.PC += 2;
  }
}

// LD Vx, kk
def _6xkk(c: *machine.Context, opcode: Opcode) {
  // Set Vx = kk
  *(c.V + opcode.x()) = opcode.data();
}

// ADD Vx, kk
def _7xkk(c: *machine.Context, opcode: Opcode) {
  // Set Vx = Vx + kk
  let x = opcode.x();
  *(c.V + x) = *(c.V + x) + opcode.data();
}

// LD Vx, Vy
def _8xy0(c: *machine.Context, opcode: Opcode) {
  // Set Vx = Vy
  *(c.V + opcode.x()) = *(c.V + opcode.y());
}

// OR Vx, Vy
def _8xy1(c: *machine.Context, opcode: Opcode) {
  // Bitwise OR. Set Vx = Vx OR Vy
  *(c.V + opcode.x()) |= *(c.V + opcode.y());
}

// AND Vx, Vy
def _8xy2(c: *machine.Context, opcode: Opcode) {
  // Bitwise AND. Set Vx = Vx AND Vy
  *(c.V + opcode.x()) &= *(c.V + opcode.y());
}

// XOR Vx, Vy
def _8xy3(c: *machine.Context, opcode: Opcode) {
  // Bitwise XOR. Set Vx = Vx XOR Vy
  *(c.V + opcode.x()) ^= *(c.V + opcode.y());
}

// ADD Vx, Vy
def _8xy4(c: *machine.Context, opcode: Opcode) {
  // Set Vx = Vx + Vy, set VF = carry.

  let x = opcode.x();
  let y = opcode.y();
  let result = uint16(*(c.V + x)) + uint16(*(c.V + y));

  *(c.V + x) = uint8(result);

  // If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, else 0
  *(c.V + 0x0F) = if result > 255 { 1; } else { 0; };
}

// SUB Vx, Vy
def _8xy5(c: *machine.Context, opcode: Opcode) {
  // Set Vx = Vx - Vy, set VF = NOT borrow.

  let x = opcode.x();
  let y = opcode.y();

  let vx = *(c.V + x);
  let vy = *(c.V + y);

  // If Vx > Vy, then VF is set to 1, otherwise 0.
  *(c.V + 0x0F) = if vx > vy { 1; } else { 0; };

  *(c.V + x) = vx - vy;
}

// SHR Vx
def _8xy6(c: *machine.Context, opcode: Opcode) {
  // Right shift. Set Vx = Vx SHR 1
  let x = opcode.x();
  let vx = *(c.V + x);

  // If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0.
  *(c.V + 0x0F) = if vx & 0x1 != 0 { 1; } else { 0; };

  *(c.V + x) = vx >> 1;
}

// SUBN Vx, Vy
def _8xy7(c: *machine.Context, opcode: Opcode) {
  // Set Vx = Vy - Vx, set VF = NOT borrow.

  let x = opcode.x();
  let y = opcode.y();

  let vx = *(c.V + x);
  let vy = *(c.V + y);

  // If Vy > Vx, then VF is set to 1, otherwise 0.
  *(c.V + 0x0F) = if vy > vx { 1; } else { 0; };

  *(c.V + x) = vy - vx;
}

// SHL Vx
def _8xyE(c: *machine.Context, opcode: Opcode) {
  // Left shift. Set Vx = Vx SHL 1
  let x = opcode.x();
  let vx = *(c.V + x);

  // If the most-significant bit of Vx is 1, then VF is set to 1, otherwise 0.
  *(c.V + 0x0F) = if vx & 0x80 != 0 { 1; } else { 0; };

  *(c.V + x) = vx << 1;
}

// SNE Vx, Vy
def _9xy0(c: *machine.Context, opcode: Opcode) {
  // Skip next instruction if Vx != Vy
  if *(c.V + opcode.x()) != *(c.V + opcode.y()) {
    c.PC += 2;
  }
}

// LD I, nnn
def _Annn(c: *machine.Context, opcode: Opcode) {
  // Set I = nnn
  c.I = opcode.address();
}

// JP V0, nnn
def _Bnnn(c: *machine.Context, opcode: Opcode) {
  // Jump to location nnn + V0
  c.PC = opcode.address() + uint16(*(c.V + 0));
}

// RND Vx, kk
def _Cxkk(c: *machine.Context, opcode: Opcode) {
  // Set Vx = random byte AND kk
  *(c.V + opcode.x()) = uint8(libc.rand() % 256) & opcode.data();
}

// DRW Vx, Vy, nibble
def _Dxyn(c: *machine.Context, opcode: Opcode) {
  // Display n-byte sprite starting at memory location I at (Vx, Vy),
  // set VF = collision. The interpreter reads n bytes from memory, starting
  // at the address stored in I. These bytes are then displayed as sprites
  // on screen at coordinates (Vx, Vy). Sprites are XORed onto the existing
  // screen. If this causes any pixels to be erased, VF is set to 1,
  // otherwise it is set to 0. If the sprite is positioned so part of it
  // is outside the coordinates of the display, it wraps around to the
  // opposite side of the screen.

  // Reset collision flag — VF
  *(c.V + 0xF) = 0;

  let sprite_size = opcode.n();
  let y = opcode.y();
  let x = opcode.x();

  let ptr = mmu.at(c, c.I);

  let i = 0;
  while i < sprite_size {
    let j = 0;
    while j < 8 {
      // Get (x, y) of the sprite pixel
      let plot_x = (*(c.V + x) + j) & (c.width - 1);
      let plot_y = (*(c.V + y) + i) & (c.height - 1);

      // Get offset into the framebuffer
      let offset = uint16(plot_y) * uint16(c.width) + uint16(plot_x);

      // Get the pixel to be set and the pixel currently set
      let p_cur = *(c.framebuffer + offset);
      let p_new = if ((*(ptr + i) >> (7 - j)) & 1) != 0 { 1; } else { 0; };

      // Set the collision flag if the displayed pixel is going to
      // be cleared.
      // NOTE: Ensure that we persist the collision flag
      //  throughout the draw loop. If it gets set once; it must
      //  be set at the end.
      *(c.V + 0xF) = if (p_cur == 1) and (p_new == 1) { 1; } else { *(c.V + 0xF); };

      // Set the pixel (with XOR)
      *(c.framebuffer + offset) ^= p_new;

      j += 1;
    }
    i += 1;
  }
}

// SKP Vx
def _Ex9E(c: *machine.Context, opcode: Opcode) {
  // Skip next instruction if key with the value of Vx is pressed

  let x = opcode.x();
  let vx = *(c.V + x);
  let state = *(c.input + vx);

  if state {
    c.PC += 2;
  }
}

// SKNP Vx
def _ExA1(c: *machine.Context, opcode: Opcode) {
  // Skip next instruction if key with the value of Vx is not pressed

  let x = opcode.x();
  let vx = *(c.V + x);
  let state = *(c.input + vx);

  if not state {
    c.PC += 2;
  }
}

// LD Vx, DT
def _Fx07(c: *machine.Context, opcode: Opcode) {
  // Set Vx = DT (Delay Timer)
  *(c.V + opcode.x()) = c.DT;
}

// LD DT, Vx
def _Fx15(c: *machine.Context, opcode: Opcode) {
  // Set DT (Delay Timer) = Vx
  c.DT = *(c.V + opcode.x());
}

// LD ST, Vx
def _Fx18(c: *machine.Context, opcode: Opcode) {
  // Set ST (Sound Timer) = Vx
  c.ST = *(c.V + opcode.x());
}

// ADD I, Vx
def _Fx1E(c: *machine.Context, opcode: Opcode) {
  // Set I = I + Vx
  c.I += uint16(*(c.V + opcode.x()));
}

// LDF I, Vx
def _Fx29(c: *machine.Context, opcode: Opcode) {
  // Set I = location of sprite for digit Vx.
  // The value of I is set to the location for the hexadecimal sprite
  // corresponding to the value of Vx.
  c.I = uint16(*(c.V + opcode.x())) * 5;
}

// BCD [I], Vx
def _Fx33(c: *machine.Context, opcode: Opcode) {
  // Write the bcd representation of Vx to memory location I through I + 2.
  let value = *(c.V + opcode.x());
  mmu.write(c, c.I + 0, value / 100);
  mmu.write(c, c.I + 1, (value % 100) / 10);
  mmu.write(c, c.I + 2, value % 10);
}

// LD [I], Vx
def _Fx55(c: *machine.Context, opcode: Opcode) {
  // Store registers V0 through Vx in memory starting at location I.
  let x = opcode.x();
  libc.memcpy(mmu.at(c, c.I), c.V, uint64(x + 1));
}

// LD Vx, [I]
def _Fx65(c: *machine.Context, opcode: Opcode) {
  // Read registers V0 through Vx from memory starting at location I.
  let x = opcode.x();
  libc.memcpy(c.V, mmu.at(c, c.I), uint64(x + 1));
}
