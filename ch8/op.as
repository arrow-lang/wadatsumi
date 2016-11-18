import "libc";

import "./machine";
import "./util";
import "./mmu";

// NOTE: Idea ..
// type Opcode = *uint8;
// implement Opcode {
//   @property
//   def X(): uint8 {
//     // [...]
//   }
// }

def execute(c: *machine.Context, opcode: *uint8) {
  let o = util.get4(opcode, 3);
  let oc = util.get16(opcode);
  let r = util.get4(opcode, 0);
  let rc = util.get8(opcode, 0);

  // libc.printf("[%04X] %04X\n", (*c).PC, oc);

  // TODO: HashMap for operations might make this look nicer

  if oc == 0x00E0 {
    _00E0(c, opcode);
  } else if oc == 0x00EE {
    _00EE(c, opcode);
  } else if oc == 0x0230 {
    _0230(c, opcode);
  } else if o == 0x1 {
    _1nnn(c, opcode);
  } else if o == 0x2 {
    _2nnn(c, opcode);
  } else if o == 0x3 {
    _3xkk(c, opcode);
  } else if o == 0x4 {
    _4xkk(c, opcode);
  } else if o == 0x5 {
    _5xy0(c, opcode);
  } else if o == 0x6 {
    _6xkk(c, opcode);
  } else if o == 0x7 {
    _7xkk(c, opcode);
  } else if o == 0x8 and r == 0x0 {
    _8xy0(c, opcode);
  } else if o == 0x8 and r == 0x1 {
    _8xy1(c, opcode);
  } else if o == 0x8 and r == 0x2 {
    _8xy2(c, opcode);
  } else if o == 0x8 and r == 0x3 {
    _8xy3(c, opcode);
  } else if o == 0x8 and r == 0x4 {
    _8xy4(c, opcode);
  } else if o == 0x8 and r == 0x5 {
    _8xy5(c, opcode);
  } else if o == 0x8 and r == 0x6 {
    _8xy6(c, opcode);
  } else if o == 0x8 and r == 0x7 {
    _8xy7(c, opcode);
  } else if o == 0x8 and r == 0xE {
    _8xyE(c, opcode);
  } else if o == 0xA {
    _Annn(c, opcode);
  } else if o == 0xB {
    _Bnnn(c, opcode);
  } else if o == 0xC {
    _Cxkk(c, opcode);
  } else if o == 0xD {
    _Dxyn(c, opcode);
  } else if o == 0xE and rc == 0x9E {
    _Ex9E(c, opcode);
  } else if o == 0xE and rc == 0xA1 {
    _ExA1(c, opcode);
  } else if o == 0xF and rc == 0x07 {
    _Fx07(c, opcode);
  } else if o == 0xF and rc == 0x15 {
    _Fx15(c, opcode);
  } else if o == 0xF and rc == 0x18 {
    _Fx18(c, opcode);
  } else if o == 0xF and rc == 0x1E {
    _Fx1E(c, opcode);
  } else if o == 0xF and rc == 0x29 {
    _Fx29(c, opcode);
  } else if o == 0xF and rc == 0x33 {
    _Fx33(c, opcode);
  } else if o == 0xF and rc == 0x55 {
    _Fx55(c, opcode);
  } else if o == 0xF and rc == 0x65 {
    _Fx65(c, opcode);
  } else {
    _unknown(opcode);
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

// CLS
def _00E0(c: *machine.Context, opcode: *uint8) {
  // Clear the Chip-8 64x32 display.
  // NOTE: Still clear this size screen, even when in High-Res mode.
  libc.memset((*c).framebuffer, 0, 32 * 64);
}

// HRCLS
def _0230(c: *machine.Context, opcode: *uint8) {
  // Clear the High-Res Chip-8 64x64 display.
  // NOTE: In normal-res mode this is identical to $00E0
  libc.memset((*c).framebuffer, 0, 64 * 64);
}

// RET
def _00EE(c: *machine.Context, opcode: *uint8) {
  // Return from a subroutine.
  // NOTE: The stack is only 16 "slots"
  (*c).SP = if (*c).SP == 0 { 0xF; } else { (*c).SP - 1; };
  (*c).PC = *((*c).stack + (*c).SP);
}

// JP nnn
def _1nnn(c: *machine.Context, opcode: *uint8) {
  // Jump to address
  (*c).PC = util.get12(opcode);
}

// CALL nnn
def _2nnn(c: *machine.Context, opcode: *uint8) {
  // Call subroutine.

  // Push PC on top of the stack.
  *((*c).stack + (*c).SP) = (*c).PC;

  // Increment the stack pointer (for the push)
  // NOTE: The stack wraps around its 16-slot area
  (*c).SP += 1;
  if (*c).SP >= 0x10 { (*c).SP = 0; }

  // Set PC to address
  (*c).PC = util.get12(opcode);
}

// SE Vx, kk
def _3xkk(c: *machine.Context, opcode: *uint8) {
  // Skip next instruction if Vx == kk
  if *((*c).V + util.get4(opcode, 2)) == util.get8(opcode, 0) {
    (*c).PC += 2;
  }
}

// SNE Vx, kk
def _4xkk(c: *machine.Context, opcode: *uint8) {
  // Skip next instruction if Vx != kk
  if *((*c).V + util.get4(opcode, 2)) != util.get8(opcode, 0) {
    (*c).PC += 2;
  }
}

// SE Vx, Vy
def _5xy0(c: *machine.Context, opcode: *uint8) {
  // Skip next instruction if Vx = Vy

  // if c.V[X(opcode)] == c.V[Y(opcode)] {
  //   c.PC += 2;
  // }

  if *((*c).V + util.get4(opcode, 2)) == *((*c).V + util.get4(opcode, 1)) {
    (*c).PC += 2;
  }
}

// LD Vx, kk
def _6xkk(c: *machine.Context, opcode: *uint8) {
  // Set Vx = kk
  *((*c).V + util.get4(opcode, 2)) = util.get8(opcode, 0);
}

// ADD Vx, kk
def _7xkk(c: *machine.Context, opcode: *uint8) {
  // Set Vx = Vx + kk
  let x = util.get4(opcode, 2);
  *((*c).V + x) = *((*c).V + x) + util.get8(opcode, 0);
}

// LD Vx, Vy
def _8xy0(c: *machine.Context, opcode: *uint8) {
  // Set Vx = Vy
  *((*c).V + util.get4(opcode, 2)) = *((*c).V + util.get4(opcode, 1));
}

// OR Vx, Vy
def _8xy1(c: *machine.Context, opcode: *uint8) {
  // Bitwise OR. Set Vx = Vx OR Vy
  *((*c).V + util.get4(opcode, 2)) |= *((*c).V + util.get4(opcode, 1));
}

// AND Vx, Vy
def _8xy2(c: *machine.Context, opcode: *uint8) {
  // Bitwise AND. Set Vx = Vx AND Vy
  *((*c).V + util.get4(opcode, 2)) &= *((*c).V + util.get4(opcode, 1));
}

// XOR Vx, Vy
def _8xy3(c: *machine.Context, opcode: *uint8) {
  // Bitwise XOR. Set Vx = Vx XOR Vy
  *((*c).V + util.get4(opcode, 2)) ^= *((*c).V + util.get4(opcode, 1));
}

// ADD Vx, Vy
def _8xy4(c: *machine.Context, opcode: *uint8) {
  // Set Vx = Vx + Vy, set VF = carry.

  let x = util.get4(opcode, 2);
  let y = util.get4(opcode, 1);
  let result = uint16(*((*c).V + x)) + uint16(*((*c).V + y));

  *((*c).V + x) = uint8(result);

  // If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, else 0
  *((*c).V + 0x0F) = if result > 255 { 1; } else { 0; };
}

// SUB Vx, Vy
def _8xy5(c: *machine.Context, opcode: *uint8) {
  // Set Vx = Vx - Vy, set VF = NOT borrow.

  let x = util.get4(opcode, 2);
  let y = util.get4(opcode, 1);

  let vx = *((*c).V + x);
  let vy = *((*c).V + y);

  // If Vx > Vy, then VF is set to 1, otherwise 0.
  *((*c).V + 0x0F) = if vx > vy { 1; } else { 0; };

  *((*c).V + x) = vx - vy;
}

// SHR Vx
def _8xy6(c: *machine.Context, opcode: *uint8) {
  // Right shift. Set Vx = Vx SHR 1
  let x = util.get4(opcode, 2);
  let vx = *((*c).V + x);

  // If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0.
  *((*c).V + 0x0F) = if vx & 0x1 != 0 { 1; } else { 0; };

  *((*c).V + x) = vx >> 1;
}

// SUBN Vx, Vy
def _8xy7(c: *machine.Context, opcode: *uint8) {
  // Set Vx = Vy - Vx, set VF = NOT borrow.

  let x = util.get4(opcode, 2);
  let y = util.get4(opcode, 1);

  let vx = *((*c).V + x);
  let vy = *((*c).V + y);

  // If Vy > Vx, then VF is set to 1, otherwise 0.
  *((*c).V + 0x0F) = if vy > vx { 1; } else { 0; };

  *((*c).V + x) = vy - vx;
}

// SHL Vx
def _8xyE(c: *machine.Context, opcode: *uint8) {
  // Left shift. Set Vx = Vx SHL 1
  let x = util.get4(opcode, 2);
  let vx = *((*c).V + x);

  // If the most-significant bit of Vx is 1, then VF is set to 1, otherwise 0.
  *((*c).V + 0x0F) = if vx & 0x80 != 0 { 1; } else { 0; };

  *((*c).V + x) = vx << 1;
}

// LD I, nnn
def _Annn(c: *machine.Context, opcode: *uint8) {
  // Set I = nnn
  (*c).I = util.get12(opcode);
}

// JP V0, nnn
def _Bnnn(c: *machine.Context, opcode: *uint8) {
  // Jump to location nnn + V0
  (*c).PC = util.get12(opcode) + uint16(*((*c).V + 0));
}

// RND Vx, kk
def _Cxkk(c: *machine.Context, opcode: *uint8) {
  // Set Vx = random byte AND kk
  *((*c).V + util.get4(opcode, 2)) = uint8(libc.rand() % 256) & util.get8(opcode, 0);
}

// DRW Vx, Vy, nibble
def _Dxyn(c: *machine.Context, opcode: *uint8) {
  // Display n-byte sprite starting at memory location I at (Vx, Vy),
  // set VF = collision. The interpreter reads n bytes from memory, starting
  // at the address stored in I. These bytes are then displayed as sprites
  // on screen at coordinates (Vx, Vy). Sprites are XORed onto the existing
  // screen. If this causes any pixels to be erased, VF is set to 1,
  // otherwise it is set to 0. If the sprite is positioned so part of it
  // is outside the coordinates of the display, it wraps around to the
  // opposite side of the screen.

  // Reset collision flag — VF
  *((*c).V + 0xF) = 0;

  let sprite_size = util.get4(opcode, 0);
  let y = util.get4(opcode, 1);
  let x = util.get4(opcode, 2);

  let ptr = mmu.at(c, (*c).I);

  let i = 0;
  while i < sprite_size {
    let j = 0;
    while j < 8 {
      // Get (x, y) of the sprite pixel
      // TODO: Wrap around width/height
      let plot_x = (*((*c).V + x) + j) & ((*c).width - 1);
      let plot_y = (*((*c).V + y) + i) & ((*c).height - 1);

      // Get offset into the framebuffer
      let offset = uint16(plot_y) * uint16((*c).width) + uint16(plot_x);

      // Get the pixel to be set and the pixel currently set
      let p_cur = *((*c).framebuffer + offset);
      let p_new = if ((*(ptr + i) >> (7 - j)) & 1) != 0 { 1; } else { 0; };

      // Set the collision flag if the displayed pixel is going to
      // be cleared.
      // NOTE: Ensure that we persist the collision flag
      //  throughout the draw loop. If it gets set once; it must
      //  be set at the end.
      *((*c).V + 0xF) = if (p_cur == 1) and (p_new == 1) { 1; } else { *((*c).V + 0xF); };

      // Set the pixel (with XOR)
      *((*c).framebuffer + offset) ^= p_new;

      j += 1;
    }
    i += 1;
  }
}

// SKP Vx
def _Ex9E(c: *machine.Context, opcode: *uint8) {
  // Skip next instruction if key with the value of Vx is pressed

  let x = util.get4(opcode, 2);
  let vx = *((*c).V + x);
  let state = *((*c).input + vx);

  if state {
    (*c).PC += 2;
  }
}

// SKNP Vx
def _ExA1(c: *machine.Context, opcode: *uint8) {
  // Skip next instruction if key with the value of Vx is not pressed

  let x = util.get4(opcode, 2);
  let vx = *((*c).V + x);
  let state = *((*c).input + vx);

  if not state {
    (*c).PC += 2;
  }
}

// LD Vx, DT
def _Fx07(c: *machine.Context, opcode: *uint8) {
  // Set Vx = DT (Delay Timer)
  *((*c).V + util.get4(opcode, 2)) = (*c).DT;
}

// LD DT, Vx
def _Fx15(c: *machine.Context, opcode: *uint8) {
  // Set DT (Delay Timer) = Vx
  (*c).DT = *((*c).V + util.get4(opcode, 2));
}

// LD ST, Vx
def _Fx18(c: *machine.Context, opcode: *uint8) {
  // Set ST (Sound Timer) = Vx
  (*c).ST = *((*c).V + util.get4(opcode, 2));
}

// ADD I, Vx
def _Fx1E(c: *machine.Context, opcode: *uint8) {
  // Set I = I + Vx
  // TODO: c.I += c.V[opcode.X()];
  (*c).I += uint16(*((*c).V + util.get4(opcode, 2)));
}

// LDF I, Vx
def _Fx29(c: *machine.Context, opcode: *uint8) {
  // Set I = location of sprite for digit Vx.
  // The value of I is set to the location for the hexadecimal sprite
  // corresponding to the value of Vx.
  (*c).I = uint16(*((*c).V + util.get4(opcode, 2))) * 5;
}

// BCD [I], Vx
def _Fx33(c: *machine.Context, opcode: *uint8) {
  // Write the bcd representation of Vx to memory location I through I + 2.
  let value = *((*c).V + util.get4(opcode, 2));
  mmu.write(c, (*c).I + 0, value / 100);
  mmu.write(c, (*c).I + 1, (value % 100) / 10);
  mmu.write(c, (*c).I + 2, value % 10);
}

// LD [I], Vx
def _Fx55(c: *machine.Context, opcode: *uint8) {
  // Store registers V0 through Vx in memory starting at location I.
  let i: uint16 = 0;
  let x = uint16(util.get4(opcode, 2));
  while i < x {
    mmu.write(c, (*c).I + i, *((*c).V + i));
    i += 1;
  }
}

// LD Vx, [I]
def _Fx65(c: *machine.Context, opcode: *uint8) {
  // Read registers V0 through Vx from memory starting at location I.
  let i: uint16 = 0;
  let x = uint16(util.get4(opcode, 2));
  while i < x {
    *((*c).V + i) = mmu.read(c, (*c).I + i);
    i += 1;
  }
}
