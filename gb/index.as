import "std";
import "libc";

import "./machine";
import "./gpu";

// TODO(wadatusmi): This code is 90~% similar to ch8/index.as

// TODO(arrow): Is this the best way to include C stuff?
#include "SDL2/SDL.h"

// BUG(arrow): This is not included right for some reason
struct SDL_AudioSpec {
  freq: libc.c_int;
  format: SDL_AudioFormat;
  channels: uint8;
  silence: uint8;
  samples: uint16;
  padding: uint16;
  size: uint32;
  callback: (*uint8, *uint8, libc.c_int) -> ();
  userdata: *uint8;
}

extern "C" def SDL_OpenAudio(desired: *SDL_AudioSpec, obtained: *SDL_AudioSpec): libc.c_int;

// BUG(arrow): CInclude does not get macros
let SDL_INIT_VIDEO: uint32 = 0x00000020;
let SDL_INIT_AUDIO: uint32 = 0x00000010;

let SCALE: uint64 = 3;
let WIDTH: uint64 = 160;
let HEIGHT: uint64 = 144;

let _window: *SDL_Window;
let _renderer: *SDL_Renderer;
let _tex: *SDL_Texture;
let _evt: *uint8;
let _running = true;

def acquire() {
  // BUG: CInclude does not support unions (yet)
  _evt = libc.malloc(1000);

  // Initialize SDL
  SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);

  // Create Window
  // TODO: Allow arbitrary scaling
  _window = SDL_CreateWindow(
    "Wadatsumi", 0x1FFF0000, 0x1FFF0000, int32(WIDTH * SCALE), int32(HEIGHT * SCALE), SDL_WINDOW_SHOWN);

  // Create _renderer
  _renderer = SDL_CreateRenderer(_window, -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

  // White initial screen
  SDL_SetRenderDrawColor(_renderer, 0, 0, 0, 255);
  SDL_RenderClear(_renderer);
  SDL_RenderPresent(_renderer);

  // Create texture
  _tex = SDL_CreateTexture(_renderer,
    SDL_PIXELFORMAT_ARGB8888,
    // BUG: CInclude has this mismatched for some reason
    int32(SDL_TEXTUREACCESS_STREAMING),
    int32(WIDTH), int32(HEIGHT));

  // Initial clear (screen)
  SDL_SetRenderDrawColor(_renderer, 255, 255, 255, 255);
  SDL_RenderClear(_renderer);
  SDL_RenderPresent(_renderer);

  // Open Audio
  let asp: SDL_AudioSpec;
  libc.memset(&asp as *uint8, 0, std.size_of<SDL_AudioSpec>());
  asp.freq = 96000;
  asp.format = 0x8010;  // Signed 16-bit samples (LE)
  asp.channels = 2;
  asp.samples = 1024;

  SDL_OpenAudio(&asp, 0 as *SDL_AudioSpec);
  SDL_PauseAudio(0);
}

def release() {
  libc.free(_evt);

  SDL_PauseAudio(1);
  SDL_CloseAudio();

  SDL_DestroyRenderer(_renderer);
  SDL_DestroyWindow(_window);
  SDL_DestroyTexture(_tex);

  SDL_Quit();
}

def render(frame: *gpu.Frame) {
  SDL_SetRenderDrawColor(_renderer, 255, 255, 255, 255);
  SDL_RenderClear(_renderer);

  SDL_UpdateTexture(_tex, 0 as *SDL_Rect, frame.Data, int32(frame.Pitch));
  SDL_RenderCopy(_renderer, _tex, 0 as *SDL_Rect, 0 as *SDL_Rect);

  SDL_RenderPresent(_renderer);
}

def main(argc: int32, argv: *str) {
  acquire();

  // let s = shell.Shell.New();
  let m = machine.Machine.New(machine.MODE_AUTO);

  // HACK: Taking the address of a reference (`self`) dies
  m.Acquire(&m);

  // Specify the external rendering method
  // m.SetOnRefresh(s.Render);
  // m.SetOnRefresh(render, &s);
  m.SetOnRefresh(render);

  m.Open(*(argv + 1));
  m.Reset();

  while _running {
    // Run a chunk of instructions
    m.Run();

    // Check for window events
    // s.Run();
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
          m.OnKeyPress(uint32(which));
        } else {
          m.OnKeyRelease(uint32(which));
        }
      }
    }
  }

  m.Release();
  // s.Release();
  release();
}
