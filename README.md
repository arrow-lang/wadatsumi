# Wadatsumi
> Gameboy (DMG) emulator written in Arrow.

### Tasks

 - Reduce code duplication among memory controllers

### Bugs

 - In "Wario Land (SML 3)"; smashing a block from below while crouching
   produces a jarring sound. My guess is the noise channel is running too fast
   in this instance.

 - In "Dragon Warrior I and II"; saving to the journal seems to indeed write to
   the journal but only the existence of said journal. No progress beyond name
   selection is remembered. "Pokemon Pinball" also doesn't appear to save
   correctly. Both games are for the Color Gameboy but are supposed to be
   GB-compatible.
