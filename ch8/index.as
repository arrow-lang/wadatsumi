import "libc";

// import "./mmu";
import "./cpu";
import "./machine";

#include "SDL2/SDL.h"

// BUG: CInclude does not get macros
let SDL_INIT_VIDEO: uint32 = 0x00000020;

let SCALE: uint64 = 10;

def main(argc: int32, argv: *str) {
  // HACK!! We need SDL structs
  let _evt: *uint8 = libc.malloc(1000);

  // Initialize Framebuffer ()
  let framebuffer: *uint32;
  framebuffer = libc.malloc(32 * 64 * 4) as *uint32;
  libc.memset(framebuffer as *uint8, 0, 32 * 64 * 4);

  // Initialize SDL
  SDL_Init(SDL_INIT_VIDEO);

  // Create Window
  // TODO: Allow scaling
  let window = SDL_CreateWindow(
    "Wadatsumi", 0x1FFF0000, 0x1FFF0000, int32(64 * SCALE), int32(32 * SCALE), SDL_WINDOW_SHOWN);

  // Create renderer
  let renderer = SDL_CreateRenderer(window, -1,
    SDL_RENDERER_ACCELERATED);

  // White initial screen
  SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
  SDL_RenderClear(renderer);
  SDL_RenderPresent(renderer);

  // Create texture
  let tex = SDL_CreateTexture(renderer,
    SDL_PIXELFORMAT_ARGB8888,
    // BUG: CInclude has this mismatched for some reason
    int32(SDL_TEXTUREACCESS_STREAMING),
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

    SDL_UpdateTexture(tex, 0 as *SDL_Rect, framebuffer as *uint8, int32(64 * 4));
    SDL_RenderCopy(renderer, tex, 0 as *SDL_Rect, 0 as *SDL_Rect);

    SDL_RenderPresent(renderer);

    // Handle Events
    if SDL_PollEvent(_evt as *SDL_Event) != 0 {
      let kind = *(_evt as *uint32);
      if kind == 0x100 {
        // Quit
        running = false;
      } else if kind == 0x300 or kind == 0x301 {
        // Key Press OR Release
        let which = (*(_evt as *SDL_KeyboardEvent)).keysym.scancode;
        // libc.printf("keyboard event %x ~ %d\n", kind, which);

        // TODO: Input map / configuration abstraction of some kind

        if (kind == 0x300) {
          machine.input_press(&c, uint32(which));
        } else {
          machine.input_release(&c, uint32(which));
        }
      }
    }

    // SDL_Delay(100);
  }

  // Finalize — Dispose context
  machine.dispose_context(&c);

  libc.free(_evt);

  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_DestroyTexture(tex);
  SDL_Quit();
}
