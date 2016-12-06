
// Channel 3 — Wave
struct ChannelWave {
  // On/Off for this channel
  Enable: bool;

  // Length — Same as channel 1/2 except that this is 8-bits and the
  //          square channels have 6-bits
  Length: uint8;
  LengthEnable: bool;

  // Volume — 2-bit code that indicates volume data
  //   00 — silence
  //   01 — (100%) data
  //   10 — ( 50%) data >> 1
  //   11 — ( 25%) data >> 2
  Volume: uint8;

  // Timer — Same as channel 1/2 except this is set to (2048-<frequency>)*2
  Timer: uint16;

  // Frequency — Same as channel 1/2
  Frequency: uint16;

  // Wave Pattern RAM (16 B)
  //  Waveform storage for arbitrary sound data
  //  Holds 32 4-bit samples that are played back upper 4 bits first
  RAM: *uint8;
}
