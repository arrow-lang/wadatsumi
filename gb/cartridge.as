import "std";
import "libc";

struct Cartridge {
  /// Filename (from ROM)
  Filename: str;

  /// Read-only Memory (from Cart)
  ROM: *uint8;

  /// ROM Size (in B)
  ROMSize: uint64;

  /// Exernal RAM (if present)
  ExternalRAM: *uint8;

  /// External RAM Size (in B)
  ExternalRAMSize: uint64;

  /// Title (in ASCII)
  Title: str;

  /// Manufacturer Code (4-bytes)
  // TODO: Manufacturer: *uint8;

  /// CGB Support Flag
  ///   00 = None (default)
  ///   80 = Game supports both CGB and GB
  ///   C0 = Game works on CGB only
  CGB: uint8;

  /// New Licensee Code (2-character, in ASCII)
  Licensee: str;

  /// SGB Support Flag
  ///   00 = None (default)
  ///   03 = Game supports SGB
  SGB: uint8;

  /// Cartridge Type
  /// NOTE: This is split up below
  ///   00 = ROM ONLY                 13 = MBC3+RAM+BATTERY
  ///   01 = MBC1                     15 = MBC4
  ///   02 = MBC1+RAM                 16 = MBC4+RAM
  ///   03 = MBC1+RAM+BATTERY         17 = MBC4+RAM+BATTERY
  ///   05 = MBC2                     19 = MBC5
  ///   06 = MBC2+BATTERY             1A = MBC5+RAM
  ///   08 = ROM+RAM                  1B = MBC5+RAM+BATTERY
  ///   09 = ROM+RAM+BATTERY          1C = MBC5+RUMBLE
  ///   0B = MMM01                    1D = MBC5+RUMBLE+RAM
  ///   0C = MMM01+RAM                1E = MBC5+RUMBLE+RAM+BATTERY
  ///   0D = MMM01+RAM+BATTERY        FC = POCKET CAMERA
  ///   0F = MBC3+TIMER+BATTERY       FD = BANDAI TAMA5
  ///   10 = MBC3+TIMER+RAM+BATTERY   FE = HuC3
  ///   11 = MBC3                     FF = HuC1+RAM+BATTERY
  ///   12 = MBC3+RAM
  Type: uint8;

  /// Memory Bank Controller (Mapper)
  ///   0 = None
  ///   1 = MBC1
  ///   2 = MBC2
  ///   3 = MMMO1
  ///   4 = MBC3
  ///   5 = MBC4
  ///   6 = MBC5
  ///   7 = POCKET CAMERA
  ///   8 = BANDAI TAMA5
  ///   9 = HuC3
  ///   A = HuC1
  MC: uint8;

  /// Components
  HasExternalRAM: bool;
  HasBattery: bool;
  HasTimer: bool;
  HasRumble: bool;
}

/// Memory Controllers
let MBC1: uint8 = 0x1;
let MBC2: uint8 = 0x2;
let MMMO1: uint8 = 0x3;
let MBC3: uint8 = 0x4;
let MBC4: uint8 = 0x5;
let MBC5: uint8 = 0x6;
let POCKET_CAMERA: uint8 = 0x7;
let BANDAI_TAMA5: uint8 = 0x8;
let HuC3: uint8 = 0x9;
let HuC1: uint8 = 0xA;

implement Cartridge {
  def New(): Self {
    let c: Cartridge;
    libc.memset(&c as *uint8, 0, std.size_of<Cartridge>());

    c.ROM = std.null<uint8>();

    return c;
  }

  def Release(self) {
    if self.ROM != std.null<uint8>() {
      libc.free(self.ROM);
    }

    if self.ExternalRAM != std.null<uint8>() {
      // Write out ERAM before release if backed by battery
      if self.HasBattery {
        self.WriteExternalSAV();
      }

      libc.free(self.ExternalRAM);
    }
  }

  def Trace(self) {
    libc.printf("debug: title             : %s\n", self.Title);
    libc.printf("debug: cartridge type    : %02X\n", self.Type);
    libc.printf("debug:   - has battery   : %d\n", self.HasBattery);
    libc.printf("debug:   - has timer     : %d\n", self.HasTimer);
    libc.printf("debug:   - has rumble    : %d\n", self.HasRumble);
    libc.printf("debug:   - has ext. ram  : %d\n", self.HasExternalRAM);
    libc.printf("debug: rom size (B)      : %d\n", self.ROMSize);
    libc.printf("debug: ext. ram size (B) : %d\n", self.ExternalRAMSize);
    libc.printf("debug: sgb support       : %s\n", "yes" if self.SGB == 3 else "no");
    libc.printf("debug: cgb support       : %s\n", if self.CGB == 0x80 {
      "yes (compat. with gb)";
    } else if self.CGB == 0xC0 {
      "yes (only on cgb)";
    } else {
      "no";
    });
  }

  def Open(self, filename: str) {
    self.Filename = filename;

    let stream = libc.fopen(filename, "rb");
    if stream == std.null<libc.FILE>() {
      libc.printf("error: couldn't read \"%s\"; couldn't open path as file\n", filename);
      libc.exit(-1);
    }

    // Determine size (in bytes) of file
    // 0 = SEEK_SET, 2 = SEEK_END
    libc.fseek(stream, 0, 2);
    let size = libc.ftell(stream);
    libc.fseek(stream, 0, 0);

    // Allocate ROM
    self.ROM = libc.malloc(uint64(size));

    // Read the file into ROM
    libc.fread(self.ROM, 1, uint64(size), stream);
    libc.fclose(stream);

    // Get ROM size
    self.ROMSize = uint64(*(self.ROM + 0x0148));
    if self.ROMSize < 0x10 {
      self.ROMSize = 32 << self.ROMSize;
    } else if self.ROMSize == 0x52 {
      self.ROMSize = 1152;
    } else if self.ROMSize == 0x53 {
      self.ROMSize = 1312;
    } else if self.ROMSize == 0x54 {
      self.ROMSize = 1536;
    }

    self.ROMSize *= 1024;

    // Get RAM size
    self.ExternalRAMSize = uint64(*(self.ROM + 0x0149));
    if self.ExternalRAMSize == 0x01 {
      self.ExternalRAMSize = 2;
    } else if self.ExternalRAMSize == 0x02 {
      self.ExternalRAMSize = 8;
    } else if self.ExternalRAMSize == 0x03 {
      self.ExternalRAMSize = 32;
    }

    self.ExternalRAMSize *= 1024;

    // Get the memory mapper code (if present)
    // TODO: Find a cleaner way to do this
    self.Type = *(self.ROM + 0x147);
    if self.Type == 0x01 {         // MBC1
      self.MC = MBC1;
    } else if self.Type == 0x02 {  // MBC1+RAM
      self.MC = MBC1;
      self.HasExternalRAM = true;
    } else if self.Type == 0x03 {  // MBC1+RAM+BATTERY
      self.MC = MBC1;
      self.HasExternalRAM = true;
      self.HasBattery = true;
    } else if self.Type == 0x05 {  // MBC2
      self.MC = MBC2;
    } else if self.Type == 0x06 {  // MBC2+BATTERY
      self.MC = MBC2;
      self.HasBattery = true;
    } else if self.Type == 0x08 {  // ROM+RAM
      self.HasExternalRAM = true;
    } else if self.Type == 0x09 {  // ROM+RAM+BATTERY
      self.HasExternalRAM = true;
      self.HasBattery = true;
    } else if self.Type == 0x0B {  // MMM01
      self.MC = MMMO1;
    } else if self.Type == 0x0C {  // MMM01+RAM
      self.MC = MMMO1;
      self.HasExternalRAM = true;
    } else if self.Type == 0x0D {  // MMM01+RAM+BATTERY
      self.MC = MMMO1;
      self.HasExternalRAM = true;
      self.HasBattery = true;
    } else if self.Type == 0x0F {  // MBC3+TIMER+BATTERY
      self.MC = MBC3;
      self.HasTimer = true;
      self.HasBattery = true;
    } else if self.Type == 0x10 {  // MBC3+TIMER+RAM+BATTERY
      self.MC = MBC3;
      self.HasTimer = true;
      self.HasBattery = true;
      self.HasExternalRAM = true;
    } else if self.Type == 0x11 {  // MBC3
      self.MC = MBC3;
    } else if self.Type == 0x12 {  // MBC3+RAM
      self.MC = MBC3;
      self.HasExternalRAM = true;
    } else if self.Type == 0x13 {  // MBC3+RAM+BATTERY
      self.MC = MBC3;
      self.HasExternalRAM = true;
      self.HasBattery = true;
    } else if self.Type == 0x15 {  // MBC4
      self.MC = MBC4;
    } else if self.Type == 0x16 {  // MBC4+RAM
      self.MC = MBC4;
      self.HasExternalRAM = true;
    } else if self.Type == 0x17 {  // MBC4+RAM+BATTERY
      self.MC = MBC4;
      self.HasExternalRAM = true;
      self.HasBattery = true;
    } else if self.Type == 0x19 {  // MBC5
      self.MC = MBC5;
    } else if self.Type == 0x1A {  // MBC5+RAM
      self.MC = MBC5;
      self.HasExternalRAM = true;
    } else if self.Type == 0x1B {  // MBC5+RAM+BATTERY
      self.MC = MBC5;
      self.HasExternalRAM = true;
      self.HasBattery = true;
    } else if self.Type == 0x1C {  // MBC5+RUMBLE
      self.MC = MBC5;
      self.HasRumble = true;
    } else if self.Type == 0x1D {  // MBC5+RUMBLE+RAM
      self.MC = MBC5;
      self.HasRumble = true;
      self.HasExternalRAM = true;
    } else if self.Type == 0x1E {  // MBC5+RUMBLE+RAM+BATTERY
      self.MC = MBC5;
      self.HasRumble = true;
      self.HasExternalRAM = true;
      self.HasBattery = true;
    } else if self.Type == 0xFC {  // POCKET CAMERA
      self.MC = POCKET_CAMERA;
    } else if self.Type == 0xFD {  // BANDAI TAMA5
      self.MC = BANDAI_TAMA5;
    } else if self.Type == 0xFE {  // HuC3
      self.MC = HuC1;
    } else if self.Type == 0xFF {  // HuC1+RAM+BATTERY
      self.MC = HuC3;
      self.HasExternalRAM = true;
      self.HasBattery = true;
    }

    // Allocate External RAM (if present)
    if self.ExternalRAMSize > 0 {
      self.ExternalRAM = libc.malloc(self.ExternalRAMSize);
    }

    // Check for existing .sav file
    if self.HasBattery {
      self.ReadExternalSAV();
    }

    // CGB Support Flag
    self.CGB = *(self.ROM + 0x0143);

    // SGB Support Flag
    self.SGB = *(self.ROM + 0x0146);

    // Get Title
    self.Title = (self.ROM + 0x0134) as str;

    // Nul out any characters in the title that are "strange"
    let i = 0;
    while i < 16 {
      let c = *(self.Title + i);
      if c < 0x20 or c >= 0x7E {
        *(self.Title + i) = 0x0;
      }

      i += 1;
    }
  }

  def ReadExternalSAV(self) {
    // Make a `.sav` filename
    // TODO(arrow): Need some string and char utilities brah
    let filenameSz = libc.strlen(self.Filename) + 2;
    let savFilename = libc.malloc(filenameSz) as *int8;
    libc.strcpy(savFilename, self.Filename);
    *(savFilename + (filenameSz - 4)) = 0x73; // s
    *(savFilename + (filenameSz - 3)) = 0x61; // a
    *(savFilename + (filenameSz - 2)) = 0x76; // v
    *(savFilename + (filenameSz - 1)) = 0;    // \x0

    // Check for an existing `.sav` file
    let stream = libc.fopen(savFilename, "rb");
    if stream != std.null<libc.FILE>() {
      // Read in saved ERAM
      libc.fread(self.ExternalRAM, 1, self.ExternalRAMSize, stream);
      libc.fclose(stream);
    }

    libc.free(savFilename as *uint8);
  }

  def WriteExternalSAV(self) {
    // Make a `.sav` filename
    // TODO(arrow): Need some string and char utilities brah
    let filenameSz = libc.strlen(self.Filename) + 2;
    let savFilename = libc.malloc(filenameSz) as *int8;
    libc.strcpy(savFilename, self.Filename);
    *(savFilename + (filenameSz - 4)) = 0x73; // s
    *(savFilename + (filenameSz - 3)) = 0x61; // a
    *(savFilename + (filenameSz - 2)) = 0x76; // v
    *(savFilename + (filenameSz - 1)) = 0;    // \x0

    // Check for an existing `.sav` file
    let stream = libc.fopen(savFilename, "wb");
    if stream != std.null<libc.FILE>() {
      // Write out saved ERAM
      libc.fwrite(self.ExternalRAM, 1, self.ExternalRAMSize, stream);
      libc.fclose(stream);
    }

    libc.free(savFilename as *uint8);
  }
}
