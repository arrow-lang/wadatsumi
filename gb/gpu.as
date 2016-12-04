import "std";
import "libc";

import "./cpu";
import "./mmu";

// BUG(arrow): wanted to do "../bits" but arrow doesn't work with that
import "./bits";

// Display width x height constants
let DISP_WIDTH = 160;
let DISP_HEIGHT = 144;

struct Frame {
  // Pixel data
  Data: *uint8;

  // Pixel pitch
  Pitch: uint32;

  // Width (in pixels)
  Width: uint32;

  // Height (in pixels)
  Height: uint32;
}

struct Sprite {
  // Y Position
  Y: uint8;

  // X Position
  X: uint8;

  // Tile/Pattern Number
  Tile: uint8;

  // Attributes/Flags
  Flags: uint8;
}

struct GPU {
  CPU: *cpu.CPU;

  // On Refresh (on V-Blank)
  OnRefresh: (*Frame) -> ();

  // Pixel data for frame that is rewritten each V-Blank
  FrameBuffer: *uint32;

  // Video RAM — 8 KiB
  VRAM: *uint8;

  // Sprite Attribute Table (OAM) — 160 Bytes
  OAM: *uint8;

  // STAT Interrupt Signal
  // Actual interrupt is triggered when this goes from 0 to 1
  STATInterruptSignal: bool;

  // Sprite X Cache
  // When sprites collide .. the sprite that started at the < X value wins
  // This cache is used to build a [x,y] => sprite.x cache used to
  // determine collision priority
  SpriteXCache: *uint8;

  // Pixel Cache
  // Array of 2-bit values where b0 is 1 if background/window was rendered
  // and b1 is 1 if a sprite was rendered
  PixelCache: *uint8;

  // Cycle counter for Mode
  Cycles: uint16;

  // FF44 - LY - LCDC Y-Coordinate (R)
  LY: uint8;

  // LYToCompare — pseudo register used to compare to LYC as the comparison
  //               is delayed by a tick after LY is set.
  LYToCompare: uint8;

  // FF41 - STAT - LCDC Status (R/W)
  // Bit 6 - LYC=LY Coincidence Interrupt (1=Enable) (Read/Write)
  LYCCoincidenceInterruptEnable: bool;

  // Bit 5 - Mode 2 OAM Interrupt         (1=Enable) (Read/Write)
  Mode2InterruptEnable: bool;

  // Bit 4 - Mode 1 V-Blank Interrupt     (1=Enable) (Read/Write)
  Mode1InterruptEnable: bool;

  // Bit 3 - Mode 0 H-Blank Interrupt     (1=Enable) (Read/Write)
  Mode0InterruptEnable: bool;

  // Bit 1-0 - Mode Flag
  //   0: H-Blank
  //   1: V-Blank
  //   2: Searching OAM-RAM
  //   3: Transferring Data to LCD Driver.
  Mode: uint8;

  // FF40 - LCDC - LCD Control
  //   Bit 7 - LCD Display Enable             (0=Off, 1=On)
  LCDEnable: bool;

  //   Bit 6 - Window Tile Map Display Select (0=9800-9BFF, 1=9C00-9FFF)
  WindowTileMapSelect: bool;

  //   Bit 5 - Window Display Enable          (0=Off, 1=On)
  WindowEnable: bool;

  //   Bit 4 - BG & Window Tile Data Select   (0=8800-97FF, 1=8000-8FFF)
  TileDataSelect: bool;

  //   Bit 3 - BG Tile Map Display Select     (0=9800-9BFF, 1=9C00-9FFF)
  BackgroundTimeMapSelect: bool;

  //   Bit 2 - OBJ (Sprite) Size              (0=8x8, 1=8x16)
  SpriteSize: bool;

  //   Bit 1 - OBJ (Sprite) Display Enable    (0=Off, 1=On)
  SpriteEnable: bool;

  //   Bit 0 - BG Display (for CGB see below) (0=Off, 1=On)
  BackgroundEnable: bool;

  // FF42 - SCY - Scroll Y (R/W)
  SCY: uint8;

  // FF43 - SCX - Scroll X (R/W)
  SCX: uint8;

  // FF45 - LYC - LY Compare (R/W)
  LYC: uint8;

  // FF4A - WY - Window Y Position (R/W)
  WY: uint8;

  // FF4B - WX - Window X Position (- 7) (R/W)
  WX: uint8;

  // FF47 - BGP — BG Palette Data (R/W)
  BGP: uint8;

  // FF48 - OBP0 - Object Palette 0 Data (R/W)
  OBP0: uint8;

  // FF49 - OBP1 - Object Palette 1 Data (R/W)
  OBP1: uint8;
}

implement GPU {
  def New(cpu_: *cpu.CPU): Self {
    let g: GPU;
    libc.memset(&g as *uint8, 0, std.size_of<GPU>());

    g.CPU = cpu_;
    g.VRAM = libc.malloc(0x2000);
    g.OAM = libc.malloc(160);
    g.FrameBuffer = libc.malloc(DISP_HEIGHT * DISP_WIDTH * 4) as *uint32;
    g.SpriteXCache = libc.malloc(DISP_HEIGHT * DISP_WIDTH);
    g.PixelCache = libc.malloc(DISP_HEIGHT * DISP_WIDTH);

    return g;
  }

  def Release(self) {
    libc.free(self.VRAM);
    libc.free(self.OAM);
    libc.free(self.FrameBuffer as *uint8);
    libc.free(self.SpriteXCache);
    libc.free(self.PixelCache);
  }

  def Reset(self) {
    libc.memset(self.VRAM, 0, 0x2000);
    libc.memset(self.OAM, 0, 160);
    libc.memset(self.FrameBuffer as *uint8, 0, (DISP_HEIGHT * DISP_WIDTH * 4));
    libc.memset(self.SpriteXCache, 0, (DISP_HEIGHT * DISP_WIDTH));
    libc.memset(self.PixelCache, 0, (DISP_HEIGHT * DISP_WIDTH));

    self.LY = 0;
    self.LYToCompare = 0;
    self.STATInterruptSignal = false;

    self.Mode = 0;
    self.Cycles = 0;
  }

  def SetOnRefresh(self, fn: (*Frame) -> ()) {
    self.OnRefresh = fn;
  }

  def Render(self) {
    if self.BackgroundEnable {
      self.RenderBackground();
    } else {
      // Background not enabled
      // TODO: Clear background and pixel cache
    }

    if self.WindowEnable {
      self.RenderWindow();
    } else {
      // Window not enabled
      // TODO: Should we do anything special here?
    }

    if self.SpriteEnable {
      self.RenderSprites();
    } else {
      // Sprites not enabled
      // TODO: Should we do anything special here?
    }
  }

  def RenderBackground(self) {
    // Line (to be rendered)
    // With a high SCY value, the line wraps around
    let line = (uint64(self.LY) + uint64(self.SCY)) & 0xFF;

    // Tile Map (Offset)
    let map = 0x1C00 if self.BackgroundTimeMapSelect else 0x1800;
    map += (line >> 3) << 5;

    let i = 0;
    let x = self.SCX % 8;
    let y = uint8(line % 8);
    let offset = uint64(self.LY) * DISP_WIDTH;

    while i < DISP_WIDTH {
      // Get pixel data of tile (and apply palette)
      let tile = self.getTile(map, (
        ((self.SCX / 8) + (x / 8)) % 32
      ), self.TileDataSelect);
      let pixel = self.getPixelForTile(tile, x % 8, y);

      // Set pixel cache
      *(self.PixelCache + offset + i) = 1 if pixel > 0 else 0;

      // Push pixel to framebuffer
      pixel = (self.BGP >> (pixel << 1)) & 0x3;
      *(self.FrameBuffer + offset + i) = self.getColorForPixel(pixel);

      x += 1;
      i += 1;
    }
  }

  def RenderWindow(self) {
    if self.LY >= self.WY {
      // Tile Map (Offset)
      let map: uint64 = 0x1C00 if self.WindowTileMapSelect else 0x1800;
      map += uint64((self.LY - self.WY) >> 3) << 5;

      let i = uint64(self.WX);
      let x: uint8 = 0;
      let y = uint8((self.LY - self.WY) % 8);
      let offset = uint64(self.LY) * DISP_WIDTH;

      while i < DISP_WIDTH {
        // Get pixel data of tile (and apply palette)
        let tile = self.getTile(map, x / 8, self.TileDataSelect);
        let pixel = self.getPixelForTile(tile, x % 8, y);

        // Set pixel cache
        *(self.PixelCache + offset + i) |= 1 if pixel > 0 else 0;

        // Push pixel to framebuffer
        pixel = (self.BGP >> (pixel << 1)) & 0x3;
        *(self.FrameBuffer + offset + i) = self.getColorForPixel(pixel);

        x += 1;
        i += 1;
      }
    }
  }

  def RenderSprites(self) {
    // Sprite attributes reside in the Sprite Attribute Table (
    // OAM - Object Attribute Memory) at $FE00-FE9F.
    // Each of the 40 entries consists of four bytes with the
    // following meanings:
    //  Byte0 - Y Position
    //  Byte1 - X Position
    //  Byte2 - Tile/Pattern Number
    //  Byte3 - Attributes/Flags:
    //    Bit7   OBJ-to-BG Priority (0=OBJ Above BG, 1=OBJ Behind BG color 1-3)
    //           (Used for both BG and Window. BG color 0 is always behind OBJ)
    //    Bit6   Y flip          (0=Normal, 1=Vertically mirrored)
    //    Bit5   X flip          (0=Normal, 1=Horizontally mirrored)
    //    Bit4   Palette number  **Non CGB Mode Only** (0=OBP0, 1=OBP1)
    //    Bit3   Tile VRAM-Bank  **CGB Mode Only**     (0=Bank 0, 1=Bank 1)
    //    Bit2-0 Palette number  **CGB Mode Only**     (OBP0-7)

    let spriteHeight = 16 if self.SpriteSize else 8;
    let i: int64 = 39;
    let n = 0;
    let offset = uint64(self.LY) * DISP_WIDTH;

    while i >= 0 {
      let s = *((self.OAM as *Sprite) + i);
      let sy = int16(s.Y) - 16;
      let sx = int16(s.X) - 8;

      // Remember, we are rendering on a line-by-line basis
      // Does this sprite intersect our current scanline?

      if (sy <= int16(self.LY)) and (sy + spriteHeight) > int16(self.LY) {

        // A maximum 10 sprites per line are allowed
        n += 1;
        if n > 10 { break; }

        // Calculate y-index into the tile (applying y-mirroring)
        let tileY = uint8(int16(self.LY) - sy);
        if bits.Test(s.Flags, 6) { tileY = uint8(spriteHeight) - 1 - tileY; }

        // Sprites can be 8x16 but Tiles are only 8x8
        if spriteHeight == 16 {
          // Adjust the tile index to point to the top or bottom tile
          if tileY < 8 {
            // Top
            s.Tile &= 0xFE;
          } else {
            // Bottom
            tileY -= 8;
            s.Tile |= 0x01;
          }
        }

        // Iterate through the columns of the sprite pixels ..
        let x = 0;
        while x < 8 {
          // Is this column of the sprite visible on the screen ?
          if (sx + x >= 0) and (sx + x < int16(DISP_WIDTH)) {
            let cacheOffset = (uint64(self.LY) * DISP_WIDTH) + uint64(sx + x);
            let xCache = *(self.SpriteXCache + cacheOffset);
            let pixelCache = *(self.PixelCache + cacheOffset);

            // Another sprite was drawn and the drawn sprite is < on the
            // X-axis
            if bits.Test(pixelCache, 1) and (xCache < uint8(sx + 8)) {
              x += 1;
              continue;
            }

            // Background/Window pixel drawn and sprite flag b7 indicates
            // that the sprite is behind the background/window
            if bits.Test(pixelCache, 0) and bits.Test(s.Flags, 7) {
              x += 1;
              continue;
            }

            // Calculate the x-index into the tile (applying x-mirroring)
            let tileX = uint8((7 - x) if bits.Test(s.Flags, 5) else x);

            // Get pixel data of tile (and apply palette)
            let pixel = self.getPixelForTile(uint16(s.Tile), tileX, tileY);
            if pixel == 0 {
              x += 1;
              continue;
            }

            // Update priority cache
            *(self.SpriteXCache + cacheOffset) = uint8(sx + 8);
            *(self.PixelCache + cacheOffset) |= 0x2;

            let palette = self.OBP1 if bits.Test(s.Flags, 4) else self.OBP0;
            pixel = (palette >> (pixel << 1)) & 0x3;

            // Push pixel to framebuffer
            let offs = offset + uint64(sx + x);
            *(self.FrameBuffer + offs) = self.getColorForPixel(pixel);
          }

          x += 1;
        }
      }

      i -= 1;
    }
  }

  // Get tile index from map
  def getTile(self, map: uint64, offset: uint8, tileDataSelect: bool): uint16 {
    return if tileDataSelect {
      uint16(*(self.VRAM + map + offset));
    } else {
      uint16(int8(*(self.VRAM + map + offset))) + 256;
    };
  }

  // Get pixel data for a specific tile and coordinates
  def getPixelForTile(self, tile: uint16, x: uint8, y: uint8): uint8 {
    let offset: uint16 = tile * 16 + uint16(y) * 2;

    return (
      ((*(self.VRAM + offset + 1) >> (7 - x) << 1) & 2) |
      ((*(self.VRAM + offset + 0) >> (7 - x)) & 1)
    );
  }

  // TODO: Make configurable
  def getColorForPixel(self, pixel: uint8): uint32 {
    return if pixel == 0 {
      // Grayscale
      0xFFFFFFFF;
      // Green
      // 0xFF9BBC0F;
      // Yellow
      // 0xFFFFFD4B;
    } else if pixel == 1 {
      // Grayscale
      0xFFC0C0C0;
      // Green
      // 0xFF8BB30F;
      // Yellow
      // 0xFFABA92F;
    } else if pixel == 2 {
      // Grayscale
      0xFF606060;
      // Green
      // 0xFF306230;
      // Yellow
      // 0xFF565413;
    } else if pixel == 3 {
      // Grayscale
      0xFF000000;
      // Green
      // 0xFF0F410F;
      // Yellow
      // 0xFF000000;
    } else {
      0;
    };
  }

  def Refresh(self) {
    let frame: Frame;
    frame.Data = self.FrameBuffer as *uint8;
    frame.Width = uint32(DISP_WIDTH);
    frame.Height = uint32(DISP_HEIGHT);
    frame.Pitch = uint32(frame.Width * 4);

    // BUG: Better hope this is not-0
    self.OnRefresh(&frame);
  }

  def Tick(self) {
    // Most activity stops when LCD is disabled
    if not self.LCDEnable { return; }

    // Increment mode cycle counter
    self.Cycles += 1;

    // LYToCompare is set to LY if it was set to a pending status of 0
    // LYToCompare is on a 1-cycle delay from LY
    if self.LYToCompare == 0 { self.LYToCompare = self.LY; }

    // Check for correct operation semantics based on mode and
    // current cycle count
    if self.Mode == 0 and self.Cycles <= 1 {
      // Each scanline (outside of VBLK) is in mode 0 for 1 cycle
      if self.LY <= 143 {
        self.Mode = 2;
      } else {
        // Enter V-Blank
        // This should occur at 70224 clocks

        self.Mode = 1;
        self.CPU.IF |= 0x01;

        self.Refresh();
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
    } else if self.Mode == 0 and self.Cycles >= (456 / 4) {
      // Each scanline lasts for exactly 456 clocks
      self.LY += 1;
      self.LYToCompare = 0;
      self.Mode = 0;
      self.Cycles -= (456 / 4);
    } else if self.Mode == 1 {
      if self.Cycles >= (456 / 4) {
        // Each scanline in VBLANK lasts for the same 456 clocks
        // Mode 1 is persisted until line-153
        if self.LY == 0 {
          self.Mode = 0;
        } else {
          self.LY += 1;
          self.LYToCompare = 0;
        }
        self.Cycles -= (456 / 4);
      } else if self.LY >= 153 and self.Cycles >= 1 {
        // Scanline counter is reset to 0 on the first cycle of #153
        self.LY = 0;
        self.LYToCompare = 0;
      }
    }

    // STAT Interrupt
    // The interrupt is fired when the signal TRANSITIONS from 0 TO 1
    // If it STAYS 1 during a screen mode change then no interrupt is fired.
    let statInterruptSignal = (
      (self.LYToCompare == self.LYC and self.LYCCoincidenceInterruptEnable) or
      (self.Mode == 0 and self.Mode0InterruptEnable) or
      (self.Mode == 2 and self.Mode2InterruptEnable) or
      (self.Mode == 1 and (
        self.Mode1InterruptEnable or self.Mode2InterruptEnable))
    );

    if not self.STATInterruptSignal and statInterruptSignal {
      self.CPU.IF |= 0x2;
    }

    self.STATInterruptSignal = statInterruptSignal;
  }

  def Read(self, address: uint16, ptr: *uint8): bool {
    *ptr = if address >= 0x8000 and address <= 0x9FFF {
      // VRAM cannot be read during mode-3
      if self.Mode == 3 {
        0xFF;
      } else {
        *(self.VRAM + (address & 0x1FFF));
      }
    } else if address >= 0xFE00 and address <= 0xFE9F {
      // OAM cannot be read during mode-2 or mode-3
      if self.Mode == 2 or self.Mode == 3 {
        0xFF;
      } else {
        *(self.OAM + (address - 0xFE00));
      }
    } else if address == 0xFF40 {
      (
        bits.Bit(self.LCDEnable, 7) |
        bits.Bit(self.WindowTileMapSelect, 6) |
        bits.Bit(self.WindowEnable, 5) |
        bits.Bit(self.TileDataSelect, 4) |
        bits.Bit(self.BackgroundTimeMapSelect, 3) |
        bits.Bit(self.SpriteSize, 2) |
        bits.Bit(self.SpriteEnable, 1) |
        bits.Bit(self.BackgroundEnable, 0)
      );
    } else if address == 0xFF41 {
      (
        bits.Bit(true, 7) |
        bits.Bit(self.LYCCoincidenceInterruptEnable, 6) |
        bits.Bit(self.Mode2InterruptEnable, 5) |
        bits.Bit(self.Mode1InterruptEnable, 4) |
        bits.Bit(self.Mode0InterruptEnable, 3) |
        bits.Bit(self.LYToCompare == self.LYC, 2) |
        self.Mode
      );
    } else if address == 0xFF42 {
      self.SCY;
    } else if address == 0xFF43 {
      self.SCX;
    } else if address == 0xFF44 {
      self.LY;
    } else if address == 0xFF45 {
      self.LYC;
    } else if address == 0xFF47 {
      self.BGP;
    } else if address == 0xFF48 {
      self.OBP0;
    } else if address == 0xFF49 {
      self.OBP1;
    } else if address == 0xFF4A {
      self.WY;
    } else if address == 0xFF4B {
      self.WX + 7;
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if address >= 0x8000 and address <= 0x9FFF {
      // VRAM cannot be written during mode-3
      if self.Mode != 3 {
        *(self.VRAM + (address & 0x1FFF)) = value;
      }
    } else if address >= 0xFE00 and address <= 0xFE9F {
      // OAM cannot be written during mode-2 or mode-3
      if self.Mode < 2 {
        *(self.OAM + (address - 0xFE00)) = value;
      }
    } else if address == 0xFF40 {
      self.LCDEnable = bits.Test(value, 7);
      self.WindowTileMapSelect = bits.Test(value, 6);
      self.WindowEnable = bits.Test(value, 5);
      self.TileDataSelect = bits.Test(value, 4);
      self.BackgroundTimeMapSelect = bits.Test(value, 3);
      self.SpriteSize = bits.Test(value, 2);
      self.SpriteEnable = bits.Test(value, 1);
      self.BackgroundEnable = bits.Test(value, 0);

      // Reset mode/scanline counters on LCD disable
      if not self.LCDEnable {
        self.LY = 0;
        self.Mode = 0;
        self.Cycles = 0;
      }
    } else if address == 0xFF41 {
      self.LYCCoincidenceInterruptEnable = bits.Test(value, 6);
      self.Mode2InterruptEnable = bits.Test(value, 5);
      self.Mode1InterruptEnable = bits.Test(value, 4);
      self.Mode0InterruptEnable = bits.Test(value, 3);
    } else if address == 0xFF42 {
      self.SCY = value;
    } else if address == 0xFF43 {
      self.SCX = value;
    } else if address == 0xFF45 {
      self.LYC = value;
    } else if address == 0xFF47 {
      self.BGP = value;
    } else if address == 0xFF48 {
      self.OBP0 = value;
    } else if address == 0xFF49 {
      self.OBP1 = value;
    } else if address == 0xFF4A {
      self.WY = value;
    } else if address == 0xFF4B {
      self.WX = (value - 7) if value > 7 else 0;
    } else {
      return false;
    }

    return true;
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

  def MCRead(this: *mmu.MemoryController, address: uint16, ptr: *uint8): bool {
    return (this.Data as *GPU).Read(address, ptr);
  }

  def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
    return (this.Data as *GPU).Write(address, value);
  }
