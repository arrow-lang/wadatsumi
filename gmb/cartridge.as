import "std";
import "libc";

struct Cartridge {
  /// Read-only Memory (from Cart)
  ROM: *uint8;

  /// ROM Size (in KiB)
  ROMSize: uint32;

  /// RAM Size (in KiB)
  RAMSize: uint32;

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
  MBC: uint8;

  /// (External) RAM
  ExternalRAM: bool;

  /// Battery-backed
  Battery: bool;

  /// Timer
  Timer: bool;

  /// Rumble
  Rumble: bool;
}

/// Memory Bank Controllers
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
  }

  def Open(self, filename: str) {
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

    // Get Title
    self.Title = (self.ROM + 0x0134) as str;

    // Get ROM size
    self.ROMSize = uint32(*(self.ROM + 0x0148));
    if self.ROMSize < 0x10 {
      self.ROMSize = 32 << self.ROMSize;
    } else if self.ROMSize == 0x52 {
      self.ROMSize = 1152;
    } else if self.ROMSize == 0x53 {
      self.ROMSize = 1312;
    } else if self.ROMSize == 0x54 {
      self.ROMSize = 1536;
    }

    // Get RAM size
    self.RAMSize = uint32(*(self.ROM + 0x0149));
    if self.RAMSize == 0x01 {
      self.RAMSize = 2;
    } else if self.RAMSize == 0x02 {
      self.RAMSize = 8;
    } else if self.RAMSize == 0x03 {
      self.RAMSize = 32;
    }

    // Get the memory mapper code (if present)
    // TODO: Find a cleaner way to do this
    self.Type = *(self.ROM + 0x147);
    if self.Type == 0x01 {         // MBC1
      self.MBC = MBC1;
    } else if self.Type == 0x02 {  // MBC1+RAM
      self.MBC = MBC1;
      self.ExternalRAM = true;
    } else if self.Type == 0x03 {  // MBC1+RAM+BATTERY
      self.MBC = MBC1;
      self.ExternalRAM = true;
      self.Battery = true;
    } else if self.Type == 0x05 {  // MBC2
      self.MBC = MBC2;
    } else if self.Type == 0x06 {  // MBC2+BATTERY
      self.MBC = MBC2;
      self.Battery = true;
    } else if self.Type == 0x08 {  // ROM+RAM
      self.ExternalRAM = true;
    } else if self.Type == 0x09 {  // ROM+RAM+BATTERY
      self.ExternalRAM = true;
      self.Battery = true;
    } else if self.Type == 0x0B {  // MMM01
      self.MBC = MMMO1;
    } else if self.Type == 0x0C {  // MMM01+RAM
      self.MBC = MMMO1;
      self.ExternalRAM = true;
    } else if self.Type == 0x0D {  // MMM01+RAM+BATTERY
      self.MBC = MMMO1;
      self.ExternalRAM = true;
      self.Battery = true;
    } else if self.Type == 0x0F {  // MBC3+TIMER+BATTERY
      self.MBC = MBC3;
      self.Timer = true;
      self.Battery = true;
    } else if self.Type == 0x10 {  // MBC3+TIMER+RAM+BATTERY
      self.MBC = MBC3;
      self.Timer = true;
      self.Battery = true;
      self.ExternalRAM = true;
    } else if self.Type == 0x11 {  // MBC3
      self.MBC = MBC3;
    } else if self.Type == 0x12 {  // MBC3+RAM
      self.MBC = MBC3;
      self.ExternalRAM = true;
    } else if self.Type == 0x13 {  // MBC3+RAM+BATTERY
      self.MBC = MBC3;
      self.ExternalRAM = true;
      self.Battery = true;
    } else if self.Type == 0x15 {  // MBC4
      self.MBC = MBC4;
    } else if self.Type == 0x16 {  // MBC4+RAM
      self.MBC = MBC4;
      self.ExternalRAM = true;
    } else if self.Type == 0x17 {  // MBC4+RAM+BATTERY
      self.MBC = MBC4;
      self.ExternalRAM = true;
      self.Battery = true;
    } else if self.Type == 0x19 {  // MBC5
      self.MBC = MBC5;
    } else if self.Type == 0x1A {  // MBC5+RAM
      self.MBC = MBC5;
      self.ExternalRAM = true;
    } else if self.Type == 0x1B {  // MBC5+RAM+BATTERY
      self.MBC = MBC5;
      self.ExternalRAM = true;
      self.Battery = true;
    } else if self.Type == 0x1C {  // MBC5+RUMBLE
      self.MBC = MBC5;
      self.Rumble = true;
    } else if self.Type == 0x1D {  // MBC5+RUMBLE+RAM
      self.MBC = MBC5;
      self.Rumble = true;
      self.ExternalRAM = true;
    } else if self.Type == 0x1E {  // MBC5+RUMBLE+RAM+BATTERY
      self.MBC = MBC5;
      self.Rumble = true;
      self.ExternalRAM = true;
      self.Battery = true;
    } else if self.Type == 0xFC {  // POCKET CAMERA
      self.MBC = POCKET_CAMERA;
    } else if self.Type == 0xFD {  // BANDAI TAMA5
      self.MBC = BANDAI_TAMA5;
    } else if self.Type == 0xFE {  // HuC3
      self.MBC = HuC1;
    } else if self.Type == 0xFF {  // HuC1+RAM+BATTERY
      self.MBC = HuC3;
      self.ExternalRAM = true;
      self.Battery = true;
    }

    // libc.printf("CART: %02X\n", self.Type);
    // libc.printf("ROM: %d\n", self.ROMSize);
    // libc.printf("RAM: %d\n", self.RAMSize);
  }
}
