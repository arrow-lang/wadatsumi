import "libc";

// import "./mmu";
import "./cpu";
import "./machine";

// BUG: Segfaults on arrow
// #include "SDL2/SDL.h"

extern def SDL_Init(flags: uint32): libc.c_int;
extern def SDL_Quit();

extern def SDL_CreateWindow(
  title: str,
  x: libc.c_int, y: libc.c_int,
  width: libc.c_int, height: libc.c_int,
  flags: uint32
): *uint8;

extern def SDL_CreateRenderer(window: *uint8, index: libc.c_int, flags: uint32): *uint8;
extern def SDL_CreateTexture(renderer: *uint8, format: uint32, access: libc.c_int, w: libc.c_int, h: libc.c_int): *uint8;

extern def SDL_DestroyWindow(window: *uint8);
extern def SDL_DestroyRenderer(renderer: *uint8);
extern def SDL_DestroyTexture(texture: *uint8);

extern def SDL_RenderClear(renderer: *uint8);
extern def SDL_SetRenderDrawColor(renderer: *uint8, r: uint8, g: uint8, b: uint8, a: uint8);
extern def SDL_RenderDrawPoint(renderer: *uint8, x: libc.c_int, y: libc.c_int);
extern def SDL_RenderPresent(renderer: *uint8);
extern def SDL_RenderCopy(renderer: *uint8, texture: *uint8, src: *uint8, dst: *uint8);

extern def SDL_UpdateTexture(texture: *uint8, rect: *uint8, pixels: *uint8, pitch: libc.c_int);

extern def SDL_Delay(ms: uint32);

struct SDL_Event {
  // Event Type
  kind: uint32;
}

extern def SDL_PollEvent(evt: *SDL_Event): bool;

let SDL_TEXTUREACCESS_STREAMING: libc.c_int = 1;

let SDL_INIT_VIDEO: uint32 = 0x00000020;

let SDL_WINDOW_SHOWN: uint32 = 0x00000004;

let SDL_RENDERER_ACCELERATED: uint32 = 0x00000002;
let SDL_RENDERER_PRESENTVSYNC: uint32 = 0x00000004;

let SDL_PIXELFORMAT_ARGB8888: uint32 = 372645892;

def main(argc: int32, argv: *str) {
  // Initialize Framebuffer ()
  let framebuffer: *uint32;
  framebuffer = libc.malloc(32 * 64 * 4) as *uint32;
  libc.memset(framebuffer as *uint8, 0, 32 * 64 * 4);

  // Initialize SDL
  SDL_Init(SDL_INIT_VIDEO);

  // Create Window
  // TODO: Allow scaling
  let window = SDL_CreateWindow(
    "Wadatsumi", 0x1FFF0000, 0x1FFF0000, 64 * 4, 32 * 4, SDL_WINDOW_SHOWN);

  // Create renderer
  let renderer = SDL_CreateRenderer(window, -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

  // White initial screen
  SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
  SDL_RenderClear(renderer);
  SDL_RenderPresent(renderer);

  // Create texture
  let tex = SDL_CreateTexture(renderer,
    SDL_PIXELFORMAT_ARGB8888,
    SDL_TEXTUREACCESS_STREAMING,
    64, 32);

  // Initialize — Create new context
  let c = machine.new_context();

  // Reset — CPU
  cpu.reset(&c);

  // Open ROM
  // [...]
  let stream = libc.fopen(*(argv + 1), "rb");

  // Get size of ROM
  libc.fseek(stream, 0, 2);
  let stream_size = libc.ftell(stream);
  libc.fseek(stream, 0, 0);

  // Write ROM into RAM
  libc.fread(c.ram, libc.size_t(if stream_size > 0xE00 { 0xE00; } else { stream_size; }), 1, stream);
  libc.fclose(stream);

  // Run
  let running = true;
  while running {
    // Execute — CPU
    cpu.execute(&c);

    // Render
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);

    let y = 0;
    while y < 32 {
      let x = 0;

      while x < 64 {
        let pixel: uint8 = *(c.framebuffer + (y * 64 + x));

        // AARRGGBB
        let color: uint32 = if pixel == 0 {
          0xFF000000;
        } else if pixel == 1 {
          0xFFFFFFFF;
        } else {
          0;
        };

        *(framebuffer + (y * 64 + x)) = color;

        x += 1;
      }

      y += 1;
    }

    SDL_UpdateTexture(tex, 0 as *uint8, framebuffer as *uint8, 64 * 4);
    SDL_RenderCopy(renderer, tex, 0 as *uint8, 0 as *uint8);

    SDL_RenderPresent(renderer);

    // Handle Events
    let evt: SDL_Event;
    if SDL_PollEvent(&evt) {
      if evt.kind == 0x100 {
        // Quit
        running = false;
      }
    }

    // SDL_Delay(100);
  }

  // Finalize — Dispose context
  machine.dispose_context(&c);

  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_DestroyTexture(tex);
  SDL_Quit();
}
