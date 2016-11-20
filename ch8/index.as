import "libc";

// import "./mmu";
import "./cpu";
import "./machine";

#include "SDL2/SDL.h"

// BUG: CInclude does not get macros (yet)
let SDL_INIT_VIDEO: uint32 = 0x00000020;

let SCALE: uint64 = 10;

let _window: *SDL_Window;
let _renderer: *SDL_Renderer;
let _tex: *SDL_Texture;
let _framebuffer: *uint32;
let _evt: *uint8;
let _running = true;

def initialize() {
  // BUG: CInclude does not support unions (yet)
  _evt = libc.malloc(1000);

  // Initialize Framebuffer ()
  _framebuffer = libc.malloc(32 * 64 * 4) as *uint32;
  libc.memset(_framebuffer as *uint8, 0, 32 * 64 * 4);

  // Initialize SDL
  SDL_Init(SDL_INIT_VIDEO);

  // Create Window
  // TODO: Allow arbitrary scaling
  _window = SDL_CreateWindow(
    "Wadatsumi", 0x1FFF0000, 0x1FFF0000, int32(64 * SCALE), int32(32 * SCALE), SDL_WINDOW_SHOWN);

  // Create _renderer
  _renderer = SDL_CreateRenderer(_window, -1,
    SDL_RENDERER_ACCELERATED);

  // White initial screen
  SDL_SetRenderDrawColor(_renderer, 0, 0, 0, 255);
  SDL_RenderClear(_renderer);
  SDL_RenderPresent(_renderer);

  // Create texture
  _tex = SDL_CreateTexture(_renderer,
    SDL_PIXELFORMAT_ARGB8888,
    // BUG: CInclude has this mismatched for some reason
    int32(SDL_TEXTUREACCESS_STREAMING),
    64, 32);
}

def release() {
  libc.free(_evt);
  libc.free(_framebuffer as *uint8);

  SDL_DestroyRenderer(_renderer);
  SDL_DestroyWindow(_window);
  SDL_DestroyTexture(_tex);

  SDL_Quit();
}

def refresh(c: *machine.Context) {
  // Render
  SDL_SetRenderDrawColor(_renderer, 0, 0, 0, 255);
  SDL_RenderClear(_renderer);

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

      *(_framebuffer + (y * 64 + x)) = color;

      x += 1;
    }

    y += 1;
  }

  SDL_UpdateTexture(_tex, 0 as *SDL_Rect, _framebuffer as *uint8, int32(64 * 4));
  SDL_RenderCopy(_renderer, _tex, 0 as *SDL_Rect, 0 as *SDL_Rect);

  SDL_RenderPresent(_renderer);
}

def poll(c: *machine.Context) {
  // Handle Events
  if SDL_PollEvent(_evt as *SDL_Event) != 0 {
    let kind = *(_evt as *uint32);
    if kind == 0x100 {
      // Quit
      _running = false;
    } else if kind == 0x300 or kind == 0x301 {
      // Key Press OR Release
      let which = (*(_evt as *SDL_KeyboardEvent)).keysym.scancode;

      // TODO: Input map / configuration abstraction of some kind

      if (kind == 0x300) {
        machine.input_press(c, uint32(which));
      } else {
        machine.input_release(c, uint32(which));
      }
    }
  }
}

def main(argc: int32, argv: *str) {
  initialize();

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

  // Machine -> On Refresh
  machine.set_on_refresh(&c, refresh);

  // Run
  // FIXME: Platform-indepdent high-res timer (not possible so we need to make a module in arrow's std)
  let clk = libc.clock();
  let elapsed: float64 = 0;
  // 540 cycles should happen each minute
  // Each cycle should take ~1852µs
  let HZ = 540;
  let RATE: float64 = ((1 / HZ) * 1000);
  let TIMER_RATE = HZ / 60;
  let counter = 0;
  while _running {
    // Execute 1 Cycle — CPU
    if elapsed >= RATE {
      cpu.execute(&c);
      elapsed -= RATE;
      counter += 1;
    }

    // Tick machine at 60hz
    if counter >= TIMER_RATE {
      machine.tick(&c);
      counter = 0;
    }

    // Increment elapsed µs count
    elapsed += float64(libc.clock() - clk) / 1_000;
    clk = libc.clock();

    // Poll — Events
    poll(&c);
  }

  // Finalize — Dispose context
  machine.dispose_context(&c);

  release();
}
