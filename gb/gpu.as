import "std";
import "libc";

import "./cpu";
import "./machine";
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
  Machine: *machine.Machine;

  // On Refresh (on V-Blank)
  OnRefresh: (*Frame) -> ();

  // Pixel data for frame that is rewritten each V-Blank
  FrameBuffer: *uint32;

  // Video RAM — 8 KiB (GB) or 16 KiB (CGB, 2 Banks)
  VRAM: *uint8;

  // FF4F - VBK - CGB Mode Only - VRAM Bank (0-1)
  VBK: uint8;

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

  // LYToCompare — LY Shadow register
  LYToCompare: uint8;

  // LY Comparison Timer
  //    When a change to LY happens; a 4 T-Cycle timer begins. After expiring
  //    LYToCompare is available and the STAT IF is flagged if enabled and
  //    matched
  LYCTimer: uint8;

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
  BackgroundTileMapSelect: bool;

  //   Bit 2 - OBJ (Sprite) Size              (0=8x8, 1=8x16)
  SpriteSize: bool;

  //   Bit 1 - OBJ (Sprite) Display Enable    (0=Off, 1=On)
  SpriteEnable: bool;

  //   Bit 0 - BG Display
  //    For  GB -> 0=Off, 1=On
  //    For CGB -> 0=Background/Window have no priority, 1=Normal priority
  BackgroundDisplay: bool;

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

  // FF68 - BCPS/BGPI - CGB Mode Only - Background Palette Index
  //    Bit 0-5   Index (00-3F)
  BCPI: uint8;
  //    Bit 7     Auto Increment  (0=Disabled, 1=Increment after Writing)
  BCPI_AutoIncrement: bool;

  // FF69 - BCPD/BGPD - CGB Mode Only - Background Palette Data (x8)
  //    Bit 0-4   Red Intensity   (00-1F)
  //    Bit 5-9   Green Intensity (00-1F)
  //    Bit 10-14 Blue Intensity  (00-1F)
  BCPD: *uint8;

  // FF6A - OCPS/OBPI - CGB Mode Only - Sprite Palette Index
  //    Same as BCPS but for the sprite palette
  OCPI: uint8;
  OCPI_AutoIncrement: bool;

  // FF6B - OCPD/OBPD - CGB Mode Only - Sprite Palette Data
  //    Same as BCDP but for the sprite palette
  OCPD: *uint8;
}

implement GPU {
  def New(machine_: *machine.Machine, cpu_: *cpu.CPU): Self {
    let g: GPU;
    libc.memset(&g as *uint8, 0, std.size_of<GPU>());

    g.CPU = cpu_;
    g.Machine = machine_;
    g.VRAM = libc.malloc(0x4000);
    g.OAM = libc.malloc(160);
    g.FrameBuffer = libc.malloc(DISP_HEIGHT * DISP_WIDTH * 4) as *uint32;
    g.SpriteXCache = libc.malloc(DISP_HEIGHT * DISP_WIDTH);
    g.PixelCache = libc.malloc(DISP_HEIGHT * DISP_WIDTH);
    g.BCPD = libc.malloc(0x40);
    g.OCPD = libc.malloc(0x40);

    return g;
  }

  def Release(self) {
    libc.free(self.VRAM);
    libc.free(self.OAM);
    libc.free(self.FrameBuffer as *uint8);
    libc.free(self.SpriteXCache);
    libc.free(self.PixelCache);
    libc.free(self.BCPD);
    libc.free(self.OCPD);
  }

  def Reset(self) {
    libc.memset(self.VRAM, 0, 0x4000);
    libc.memset(self.OAM, 0, 160);
    libc.memset(self.FrameBuffer as *uint8, 0, (DISP_HEIGHT * DISP_WIDTH * 4));
    libc.memset(self.SpriteXCache, 0, (DISP_HEIGHT * DISP_WIDTH));
    libc.memset(self.PixelCache, 0, (DISP_HEIGHT * DISP_WIDTH));

    self.LY = 0;
    self.LYToCompare = 0;
    self.LYCTimer = 0;
    self.STATInterruptSignal = false;

    self.Mode = 0;
    self.Cycles = 0;

    self.BGP = 0xFC;
    self.OBP0 = 0xFF if self.Machine.Mode == machine.MODE_GB else 0;
    self.OBP1 = 0xFF if self.Machine.Mode == machine.MODE_GB else 0;

    if self.Machine.Mode == machine.MODE_CGB {
      // Initialize color palettes to white — each color is 2 bytes ($7FFF)
      let i = 0;
      while i < 0x40 {
        let c = uint8(0xFF if i % 2 == 0 else 0x7F);

        *(self.BCPD + i) = c;
        *(self.OCPD + i) = c;

        i += 1;
      }

      // Initialize palette indexes and turn auto-increment on
      // Values come from mooneye's tests
      self.BCPI = 0x08;
      self.BCPI_AutoIncrement = true;
      self.OCPI = 0x10;
      self.OCPI_AutoIncrement = true;
    }
  }

  def SetOnRefresh(self, fn: (*Frame) -> ()) {
    self.OnRefresh = fn;
  }

  def Render(self) {
    // Clear line
    let i = 0;
    let offset = uint64(self.LY) * DISP_WIDTH;
    while i < DISP_WIDTH {
      *(self.PixelCache + offset + i) = 0;
      *(self.FrameBuffer + offset + i) = 0xFFFFFFFF;
      i += 1;
    }

    if self.LCDEnable and (self.Machine.Mode == machine.MODE_CGB or self.BackgroundDisplay) {
      self.RenderBackground();
    } else {
      // Background not enabled
      // TODO: Clear background and pixel cache
    }

    if self.LCDEnable and self.WindowEnable {
      self.RenderWindow();
    } else {
      // Window not enabled
      // TODO: Should we do anything special here?
    }

    if self.LCDEnable and self.SpriteEnable {
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
    let map = 0x1C00 if self.BackgroundTileMapSelect else 0x1800;
    map += (line >> 3) << 5;

    let i = 0;
    let x = self.SCX % 8;
    let y = uint8(line % 8);
    let offset = uint64(self.LY) * DISP_WIDTH;

    while i < DISP_WIDTH {
      let mapOffset = ((self.SCX / 8) + (x / 8)) % 32;

      // Get background attributes for background tile (if CGB)
      let attr = 0;
      if self.Machine.Mode == machine.MODE_CGB {
        attr = *(self.VRAM + (0x2000 + map + uint64(mapOffset)));
      }

      // Get pixel data of tile
      let tile = self.getTile(map, mapOffset, self.TileDataSelect);

      let tileX = (7 - (x % 8)) if bits.Test(attr, 5) else (x % 8);
      let tileY = (7 - y) if bits.Test(attr, 6) else y;

      let pixel = self.getPixelForTile(tile, tileX, tileY, (attr & 0x8) >> 3);

      if self.Machine.Mode == machine.MODE_GB or self.BackgroundDisplay {
        // Set pixel cache
        *(self.PixelCache + offset + i) = 1 if pixel > 0 else 0;
      }

      if self.Machine.Mode == machine.MODE_CGB and (attr & 0x80) != 0 and self.BackgroundDisplay {
        // Force priority of this tile (over sprites)
        *(self.PixelCache + offset + i) |= 0b100 if pixel > 0 else 0;
      }

      // Apply palette and color processing
      let color = if self.Machine.Mode == machine.MODE_CGB {
        self.getColorForColorPixel(pixel, self.BCPD, attr & 0b111);
      } else {
        self.getColorForMonoPixel(pixel, self.BGP);
      };

      // Push pixel to framebuffer
      *(self.FrameBuffer + offset + i) = color;

      x += 1;
      i += 1;
    }
  }

  def RenderWindow(self) {
    if self.LY >= self.WY {
      // Tile Map (Offset)
      let map: uint64 = 0x1C00 if self.WindowTileMapSelect else 0x1800;
      map += uint64((self.LY - self.WY) >> 3) << 5;

      let i = uint64((self.WX - 7) if self.WX > 7 else 0);
      let x: uint8 = 0;
      let y = uint8((self.LY - self.WY) % 8);
      let offset = uint64(self.LY) * DISP_WIDTH;

      while i < DISP_WIDTH {
        let mapOffset = x / 8;

        // Get background attributes for background tile (if CGB)
        let attr = 0;
        if self.Machine.Mode == machine.MODE_CGB {
          attr = *(self.VRAM + (0x2000 + map + uint64(mapOffset)));
        }

        // Get pixel data of tile (and apply palette)
        let tile = self.getTile(map, mapOffset, self.TileDataSelect);

        let tileX = (7 - (x % 8)) if bits.Test(attr, 5) else (x % 8);
        let tileY = (7 - y) if bits.Test(attr, 6) else y;

        let pixel = self.getPixelForTile(
          tile, tileX, tileY, (attr & 0x8) >> 3);

        if self.Machine.Mode == machine.MODE_GB or self.BackgroundDisplay {
          // Set pixel cache
          *(self.PixelCache + offset + i) = 1 if pixel > 0 else 0;
        }

        if self.Machine.Mode == machine.MODE_CGB and (attr & 0x80) != 0 and self.BackgroundDisplay {
          // Force priority of this tile (over sprites)
          *(self.PixelCache + offset + i) |= 0b100 if pixel > 0 else 0;
        }

        // Apply palette and color processing
        let color = if self.Machine.Mode == machine.MODE_CGB {
          self.getColorForColorPixel(pixel, self.BCPD, attr & 0b111);
        } else {
          self.getColorForMonoPixel(pixel, self.BGP);
        };

        // Push pixel to framebuffer
        *(self.FrameBuffer + offset + i) = color;

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
    let i = 0;
    let n = 0;
    let offset = uint64(self.LY) * DISP_WIDTH;

    while i < 40 {
      let s = *((self.OAM as *Sprite) + i);
      let sy = int16(s.Y) - 16;
      let sx = int16(s.X) - 8;

      // Ensure bits 3-0 are clear in GB mode (CGB attrs)
      if self.Machine.Mode == machine.MODE_GB { s.Flags &= ~0b1111; }

      // Remember, we are rendering on a line-by-line basis
      // Does this sprite intersect our current scanline?

      if (sy <= int16(self.LY)) and (sy + spriteHeight) > int16(self.LY) {

        // A maximum 10 sprites per line are allowed
        // n += 1;
        if n >= 10 { break; }

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
        let rendered = false;
        while x < 8 {
          // Is this column of the sprite visible on the screen ?
          if (sx + x >= 0) and (sx + x < int16(DISP_WIDTH)) {
            let cacheOffset = (uint64(self.LY) * DISP_WIDTH) + uint64(sx + x);
            let xCache = *(self.SpriteXCache + cacheOffset);
            let pixelCache = *(self.PixelCache + cacheOffset);

            // Another sprite was drawn and the drawn sprite is < on the
            // X-axis (only checked in GB mode)
            if self.Machine.Mode == machine.MODE_GB and bits.Test(pixelCache, 1) and (xCache <= uint8(sx + 8)) {
              x += 1;
              continue;
            }

            // In CGB mode; there is a override bit that can be set which
            // forces sprites to bow down to the background layers
            if bits.Test(pixelCache, 2) {
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
            let pixel = self.getPixelForTile(
              uint16(s.Tile), tileX, tileY, (s.Flags & 0x8) >> 3);

            // Update priority cache
            *(self.PixelCache + cacheOffset) |= 0x2 if pixel > 0 else 0;
            *(self.SpriteXCache + cacheOffset) = uint8(sx + 8);

            // Mark this sprite as rendered
            rendered = true;

            // Skip if transparent
            if pixel == 0 {
              x += 1;
              continue;
            }

            // Apply palette and color processing
            let color = if self.Machine.Mode == machine.MODE_CGB {
              self.getColorForColorPixel(pixel, self.OCPD, s.Flags & 0b111);
            } else {
              let palette = self.OBP1 if bits.Test(s.Flags, 4) else self.OBP0;
              self.getColorForMonoPixel(pixel, palette);
            };

            // Push pixel to framebuffer
            *(self.FrameBuffer + (offset + uint64(sx + x))) = color;
          } else {
            // Off screen (with X) still counts as rendered
            rendered = true;
          }

          x += 1;
        }

        if rendered {
          n += 1;
        }
      }

      i += 1;
    }
  }

  // Get tile index from map
  def getTile(self, map: uint64, offset: uint8, tileDataSelect: bool): uint16 {
    return if tileDataSelect {
      uint16(*(self.VRAM + map + uint64(offset)));
    } else {
      uint16(int8(*(self.VRAM + map + uint64(offset)))) + 256;
    };
  }

  // Get pixel data for a specific tile and coordinates
  def getPixelForTile(self, tile: uint16, x: uint8, y: uint8, bank: uint8): uint8 {
    let offset: uint16 = tile * 16 + uint16(y) * 2;

    return (
      ((*(self.VRAM + (0x2000 * uint16(bank)) + offset + 1) >> (7 - x) << 1) & 2) |
      ((*(self.VRAM + (0x2000 * uint16(bank)) + offset + 0) >> (7 - x)) & 1)
    );
  }

  // TODO: Make configurable
  def getColorForMonoPixel(self, pixel: uint8, palette: uint8): uint32 {
    pixel = (palette >> (pixel << 1)) & 0x3;
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

  def getColorForColorPixel(self,
    pixel: uint8,
    palette: *uint8,
    paletteIndex: uint8
  ): uint32 {
    // Every 8-bytes is a new entry and each entry is 0-3 according to the
    // tile data
    let index = (paletteIndex << 3) + (pixel << 1);
    let paltteEntryLo = *(palette + index + 0);
    let paltteEntryHi = *(palette + index + 1);
    let red = paltteEntryLo & 0x1F;
    let green = ((paltteEntryLo >> 5) | ((paltteEntryHi & 0x3) << 3)) & 0x1F;
    let blue = (paltteEntryHi >> 2) & 0x1F;

    // TODO: Find and use a lookup table instead.. I'm sure its not an even
    //       gamut

    let r = (uint32(red) * 255) / 31;
    let g = (uint32(green) * 255) / 31;
    let b = (uint32(blue) * 255) / 31;

    return 0xFF000000 | (r << 16) | (g << 8) | b;
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
    // Most activity stops when LCD is disabled (?)
    if not self.LCDEnable { return; }

    // Tick is called each M-Cycle but the GPU runs on T-Cycles
    let i = 0;
    while i < 4 {
      // Mode to use for STAT comparisions (if at $FF, we just use self.Mode)
      let modeSTAT = 0xFF;

      // Increment cycle counter (reset to 0 at the beginning of each scanline)
      self.Cycles += 1;

      // LY is compared on a 4 T-Cycle delay from its changes
      if self.LYCTimer > 0 { self.LYCTimer -= 1; }

      // A scanline starts in mode 0 (for 4 T-Cycles), proceeds to mode 2,
      //  then goes to mode 3 and, when the LCD controller has finished
      //  drawing the line (which depends on a lot) it goes to mode 0.
      //  During lines 144-153 the LCD controller is in mode 1.

      // The V-Blank interrupt is triggered when the LCD controller
      // enters the VBL screen mode (mode 1, LY=144).

      // V-Blank lasts 4560 T-cycles (9120 in double-speed mode).

      if self.Mode == 0 and self.Cycles == 4 {
        // Scanlines 1-144 start in mode 0 for the first few T-Cycles
        if self.LY == 144 {
          // Proceed to mode 1 — V-Blank
          self.Mode = 1;
          self.CPU.IF |= 0x01;

          // Trigger the front-end to refresh the scren
          self.Refresh();
        } else {
          // Proceed to mode 2 — Searching OAM-RAM
          self.Mode = 2;
        }
      } else if self.Mode == 2 and self.Cycles == 88 {
        // Proceed to mode 3 — Transferring Data to LCD Driver
        self.Mode = 3;
      } else if self.Mode == 3 and self.Cycles == 256 {
        // The mode 3 / H-Blank STAT interrupt is signalled 1 T-Cycle
        // before mode 3 itself for reasons unknown to mere mortals
        modeSTAT = 0;
      } else if self.Mode == 3 and self.Cycles == 257 {
        // Mode 3 ends at 254 T-Cycles at BASE (no sprites or SCX funky junk)
        // TODO: https://www.reddit.com/r/EmuDev/comments/59pawp/gb_mode3_sprite_timing/?st=iw9j5tnl&sh=6825f812
        //       Need to determine proper length of mode-3

        // Proceed to mode 0 — H-Blank
        self.Mode = 0;

        // Render scanline
        self.Render();
      } else if self.Mode == 0 and self.Cycles == 452 {
        // A scanline takes 456 T-Cycles to complete (912 in double-speed mode)
        self.LY += 1;
        self.LYToCompare = self.LY;
        self.LYCTimer = 4;
        self.Mode = 0;
      } else if self.Mode == 1 {
        if self.Cycles == 452 {
          if self.LY == 0 {
            // Restart process (back to top of LCD)
            self.Mode = 0;
          } else {
            self.LY += 1;
            self.LYToCompare = self.LY;
            self.LYCTimer = 4;
          }
        } else if self.LY == 153 and self.Cycles == 4 {
          // Scanline 153 spends only 4 T-Cycles with LY == 153
          self.LY = 0;
          self.LYToCompare = self.LY;
          self.LYCTimer = 4;
        }
      }

      if self.Cycles == 456 {
        // Reset cycle counter (end of scanline)
        self.Cycles = 0;
      }

      // STAT Interrupt
      // The interrupt is fired when the signal TRANSITIONS from 0 TO 1
      // If it STAYS 1 during a screen mode change then no interrupt is fired.
      if modeSTAT == 0xFF { modeSTAT = self.Mode; }
      let statInterruptSignal = (
        ((self.LYToCompare == self.LYC) and self.LYCCoincidenceInterruptEnable) or
        (modeSTAT == 0 and self.Mode0InterruptEnable) or
        (modeSTAT == 2 and self.Mode2InterruptEnable) or
        (modeSTAT == 1 and (
          self.Mode1InterruptEnable or self.Mode2InterruptEnable))
      );

      if not self.STATInterruptSignal and statInterruptSignal {
        self.CPU.IF |= 0x2;
      }

      self.STATInterruptSignal = statInterruptSignal;

      i += 1;
    }
  }

  def Read(self, address: uint16, ptr: *uint8): bool {
    *ptr = if address >= 0x8000 and address <= 0x9FFF {
      // VRAM cannot be read during mode-3
      if self.Mode == 3 {
        0xFF;
      } else {
        *(self.VRAM + (0x2000 * uint16(self.VBK)) + (address & 0x1FFF));
      }
    } else if address >= 0xFE00 and address <= 0xFE9F {
      // OAM cannot be read during mode-2 or mode-3
      if (self.Mode == 2 or self.Mode == 3) {
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
        bits.Bit(self.BackgroundTileMapSelect, 3) |
        bits.Bit(self.SpriteSize, 2) |
        bits.Bit(self.SpriteEnable, 1) |
        bits.Bit(self.BackgroundDisplay, 0)
      );
    } else if address == 0xFF41 {
      (
        bits.Bit(true, 7) |
        bits.Bit(self.LYCCoincidenceInterruptEnable, 6) |
        bits.Bit(self.Mode2InterruptEnable, 5) |
        bits.Bit(self.Mode1InterruptEnable, 4) |
        bits.Bit(self.Mode0InterruptEnable, 3) |
        bits.Bit(self.LYCTimer == 0 and (self.LYToCompare == self.LYC), 2) |
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
      self.WX;
    } else if address == 0xFF4F and self.Machine.Mode == machine.MODE_CGB {
      (self.VBK | 0b1111_1110);
    } else if address == 0xFF68 and self.Machine.Mode == machine.MODE_CGB {
      (self.BCPI | 0x40 | bits.Bit(self.BCPI_AutoIncrement, 7));
    } else if address == 0xFF69 and self.Machine.Mode == machine.MODE_CGB {
      ((*(self.BCPD + self.BCPI)) | ((self.BCPI % 2) * 0x80));
    } else if address == 0xFF6A and self.Machine.Mode == machine.MODE_CGB {
      (self.OCPI | 0x40 | bits.Bit(self.OCPI_AutoIncrement, 7));
    } else if address == 0xFF6B and self.Machine.Mode == machine.MODE_CGB {
      ((*(self.OCPD + self.OCPI)) | ((self.OCPI % 2) * 0x80));
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if address >= 0x8000 and address <= 0x9FFF {
      // VRAM cannot be written during mode-3 (?)
      // if self.Mode != 3 {
      *(self.VRAM + (0x2000 * uint16(self.VBK)) + (address & 0x1FFF)) = value;
      // }
    } else if address >= 0xFE00 and address <= 0xFE9F {
      // OAM cannot be written during mode-2 or mode-3 (?)
      // if self.Mode != 3 and self.Mode != 2 {
      *(self.OAM + (address - 0xFE00)) = value;
      // }
    } else if address == 0xFF40 {
      self.LCDEnable = bits.Test(value, 7);
      self.WindowTileMapSelect = bits.Test(value, 6);
      self.WindowEnable = bits.Test(value, 5);
      self.TileDataSelect = bits.Test(value, 4);
      self.BackgroundTileMapSelect = bits.Test(value, 3);
      self.SpriteSize = bits.Test(value, 2);
      self.SpriteEnable = bits.Test(value, 1);
      self.BackgroundDisplay = bits.Test(value, 0);

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
      self.WX = value;
    } else if address == 0xFF4F and self.Machine.Mode == machine.MODE_CGB {
      self.VBK = value & 0x1;
    } else if address == 0xFF68 and self.Machine.Mode == machine.MODE_CGB {
      self.BCPI = value & 0x3F;
      self.BCPI_AutoIncrement = bits.Test(value, 7);
    } else if address == 0xFF69 and self.Machine.Mode == machine.MODE_CGB {
      *(self.BCPD + self.BCPI) = (value & ~((self.BCPI % 2) * 0x80));

      // Auto-increment BCPS
      if self.BCPI_AutoIncrement {
        self.BCPI += 1;
        self.BCPI &= 0x3F;
      }
    } else if address == 0xFF6A and self.Machine.Mode == machine.MODE_CGB {
      self.OCPI = value & 0x3F;
      self.OCPI_AutoIncrement = bits.Test(value, 7);
    } else if address == 0xFF6B and self.Machine.Mode == machine.MODE_CGB {
      *(self.OCPD + self.OCPI) = (value & ~((self.OCPI % 2) * 0x80));

      // Auto-increment OCPI
      if self.OCPI_AutoIncrement {
        self.OCPI += 1;
        self.OCPI &= 0x3F;
      }
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
