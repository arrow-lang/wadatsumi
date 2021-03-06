# Wadatsumi
> Gameboy (DMG) emulator written in Arrow.

### Tasks

 - BIOS

 - Sprite / Mode-3 Timing

 - Reduce code duplication among memory controllers

 - Prevent opposite directions on the D-Pad from being pressed simultaneously (
   doing so locks up some games like "Pocket Bomberman")

 - [CGB] H-Blank DMA

 - MBC3 Timer

 - MBC5 Rumble

 - Command Line Arguments
    - `-m gb` and `-m cgb` to select mode
    - `--scale` / `-s` to specify the scale factor
    - `--audio-sample-rate` to specify the audio sample rate

 - When the LCD is enabled we should still emit "refresh" events to the
   front-end to keep up with V-Sync

### Bugs

 - In "Wario Land (SML 3)"; smashing a block from below while crouching
   produces a jarring sound. My guess is the noise channel is running too fast
   in this instance.

 - In "Dragon Warrior I and II"; saving to the journal seems to indeed write to
   the journal but only the existence of said journal. No progress beyond name
   selection is remembered. "Pokemon Pinball" also doesn't appear to save
   correctly. Both games are for the Color Gameboy but are supposed to be
   GB-compatible.

 - In "Pokemon Trading Card Game"; I get an immediate white screen and then
   it seems to freeze
