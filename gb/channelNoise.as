
// Channel 4 — Noise
struct ChannelNoise {
  // Volume * — Same as channel 1/2
  Volume: uint8;
  VolumeInitial: uint8;
  VolumeEnvelopeTimer: uint8;
  VolumeEnvelopePeriod: uint8;
  VolumeEnvelopeDirection: bool;

  // Length — Same as channel 1/2
  Length: uint8;
  LengthEnable: bool;

  // Timer — Same operation as channel 1/2 but set to:
  //         <divisor> << <frequency>
  Timer: uint16;

  // Shift Clock Frequency — 4 bits
  Frequency: uint8;

  // Counter Step/Width
  //  false=15 bits, true=7 bits
  CounterWidth: bool;

  // Divisor Index
  DivisorIndex: uint8;
}


  // // Channel 3 - Wave Output
  // // -----------------------
  //
  // // FF1A - NR30 - Channel 3 Sound on/off (R/W)
  // //    Bit 7 - Sound Channel 3 Off  (0=Stop, 1=Playback)  (Read/Write)
  // NR30: uint8;
  //
  // // FF1B - NR31 - Channel 3 Sound Length (R/W)
  // //    Bit 7-0 - Sound length (t1: 0 - 255)
  // NR31: uint8;
  //
  // // FF1C - NR32 - Channel 3 Select output level (R/W)
  // //    Bit 6-5 - Select output level (Read/Write)
  // NR32: uint8;
  //
  // // FF1D - NR33 - Channel 3 Frequency's lower data (W)
  // NR33: uint8;
  //
  // // FF1E - NR34 - Channel 3 Frequency's higher data (R/W)
  // //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  // //    Bit 6   - Counter/consecutive selection (Read/Write)
  // //              (1=Stop output when length in NR31 expires)
  // //    Bit 2-0 - Frequency's higher 3 bits (x) (Write Only)
  // NR34: uint8;
  //
  // // FF30-FF3F - Wave Pattern RAM (16 bytes)
  // // Contents - Waveform storage for arbitrary sound data
  // C3_WavePatternRAM: *uint8;
  //
  // // Channel 4 - Noise
  // // -----------------
  //
  // // FF20 - NR41 - Channel 4 Sound Length (R/W)
  // //    Bit 5-0 - Sound length data (t1: 0-63)
  // NR41: uint8;
  //
  // // FF21 - NR42 - Channel 4 Volume Envelope (R/W)
  // //    Bit 7-4 - Initial Volume of envelope (0-0Fh) (0=No Sound)
  // //    Bit 3   - Envelope Direction (0=Decrease, 1=Increase)
  // //    Bit 2-0 - Number of envelope sweep (n: 0-7)
  // //              (If zero, stop envelope operation.)
  // NR42: uint8;
  //
  // // FF22 - NR43 - Channel 4 Polynomial Counter (R/W)
  // //    Bit 7-4 - Shift Clock Frequency (s)
  // //    Bit 3   - Counter Step/Width (0=15 bits, 1=7 bits)
  // //    Bit 2-0 - Dividing Ratio of Frequencies (r)
  // NR43: uint8;
  //
  // // FF23 - NR44 - Channel 4 Counter/consecutive; Inital (R/W)
  // //    Bit 7   - Initial (1=Restart Sound)     (Write Only)
  // //    Bit 6   - Counter/consecutive selection (Read/Write)
  // //              (1=Stop output when length in NR41 expires)
  // NR44: uint8;
