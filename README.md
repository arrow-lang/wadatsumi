# Wadatsumi
> Gameboy (DMG) emulator written in Arrow.

### Tasks

 - Reduce code duplication among memory controllers

 - Prevent opposite directions on the D-Pad from being pressed simultaneously (
   doing so locks up some games like "Pocket Bomberman")

 - [CGB] Implement simplified sprite priority when in CGB mode (no x-cache)

 - [CGB] Background can override OAM priority
 - [CGB] Background/Window can be told to have lower priority 100% with LCDC

 - Command Line Arguments
    - `-m gb` and `-m cgb` to select mode
    - `--scale` / `-s` to specify the scale factor
    - `--audio-sample-rate` to specify the audio sample rate

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

 - In "Donkey Kong"; if you hold <START> while the game boots it tries to
   execute opcode $FD (illegal)

 - In "Donkey Kong"; there are painful graphical glitches between levels

 - In "Donkey Kong"; there are just a ton of small glitches
