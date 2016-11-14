import "libc";

import "./machine";
import "./util";
import "./mmu";

def execute(c: *machine.Context, opcode: *uint8) {
  let o = util.get4(opcode, 3);
  let oc = util.get16(opcode);
  let r = util.get8(opcode, 0);

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
  } else if o == 0x6 {
    _6xkk(c, opcode);
  } else if o == 0xA {
    _Annn(c, opcode);
  } else if o == 0xD {
    _Dxyn(c, opcode);
  } else if o == 0xF and r == 0x33 {
    _Fx33(c, opcode);
  } else {
    _unknown(opcode);
  }

  // Increment PC
  (*c).PC += 2;
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
  // TODO: os.clear_screen(64, 32);
}

// HRCLS
def _0230(c: *machine.Context, opcode: *uint8) {
  // Clear the High-Res Chip-8 64x64 display.
  // NOTE: In normal-res mode this is identical to $00E0
  // TODO: os.clear_screen(64, (*c).height);
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
def _3xkk(c: *machine.Context, opcode: *uint8) {
  // Skip next instruction if Vx != kk
  if *((*c).V + util.get4(opcode, 2)) != util.get8(opcode, 0) {
    (*c).PC += 2;
  }
}

// LD Vx, kk
def _6xkk(c: *machine.Context, opcode: *uint8) {
  // Set Vx = kk
  *((*c).V + util.get4(opcode, 2)) = util.get8(opcode, 0);
}

// LD I, nnn
def _Annn(c: *machine.Context, opcode: *uint8) {
  // Set I = nnn
  (*c).I = util.get12(opcode);
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

  libc.printf("DRAW: (V%d, V%d) x %d @ %04X\n", x, y, sprite_size, (*c).I);

  let ptr = mmu.at(c, (*c).I);


  let i = 0;
  while i < sprite_size {
    let j = 0;
    while j < 8 {
      // Get (x, y) of the sprite pixel
      // TODO: Wrap around width/height
      let plot_x = *((*c).V + x) + j;
      let plot_y = *((*c).V + y) + i;

      // Get offset into the framebuffer
      let offset = uint16(plot_y) * (*c).width * uint16(plot_x);

      // Get the pixel to be set and the pixel currently set
      let p_cur = *((*c).framebuffer + offset);
      let p_new = if ((*(ptr + i) >> (7 - j)) & 1) != 0 { 1; } else { 0; };

      // Set the collision flag if the displayed pixel is going to
      // be cleared.
      // NOTE: Ensure that we persist the collision flag
      //  throughout the draw loop. If it gets set once; it must
      //  be set at the end.
      *((*c).V + 0xF) = if p_cur == p_new { 1; } else { *((*c).V + 0xF); };

      // Set the pixel (with XOR)
      *((*c).framebuffer + offset) ^= p_new;

      j += 1;
    }
    i += 1;
  }
}

// BCD [I], Vx
def _Fx33(c: *machine.Context, opcode: *uint8) {
  // Write the bcd representation of Vx to memory location I through I + 2.
  let value = *((*c).V + util.get4(opcode, 2));
  mmu.write(c, (*c).I + 0, value / 100);
  mmu.write(c, (*c).I + 1, (value % 100) / 10);
  mmu.write(c, (*c).I + 2, value % 10);
}
