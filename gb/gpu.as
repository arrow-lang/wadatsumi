import "libc";

struct GPU {
  // Video RAM — 8 KiB
  VRAM: *uint8;
}

implement GPU {
  def New(): Self {
    let g: GPU;
    g.VRAM = libc.malloc(0x2000);

    return g;
  }

  def Release(self) {
    libc.free(g.VRAM);
  }

  def Tick(self) {
    // [..]
  }
}
