import "std";
import "libc";
import "time";

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

  // Parse command line arguments (a bit)
  // TODO: Build a real arg parse for arrow

  let is_test: bool = false;
  let test_output_filename: str;
  let input_filename: str;
  let selected_mode = machine.MODE_AUTO;

  let i = 1;
  while i < argc {
    let arg = *(argv + i);

    if *(arg + 0) == 0x2D and *(arg + 1) == 0x2D {
      // Option
      if libc.strcmp("test", arg + 2) == 0 {
        // --test
        // Mark test mode
        is_test = true;
      } else if libc.strcmp("test-output", arg + 2) == 0 {
        // --test-output <filename>
        i += 1;
        test_output_filename = *(argv + i);
      } else if libc.strcmp("mode", arg + 2) == 0 {
        // --mode <mode>
        i += 1;
        let mode_str = *(argv + i);
        if libc.strcmp("gb", mode_str) == 0 {
          selected_mode = machine.MODE_GB;
        } else if libc.strcmp("cgb", mode_str) == 0 {
          selected_mode = machine.MODE_CGB;
        }
      }

    } else {
      // Filename (and we're out)
      input_filename = arg;
      break;
    }

    i += 1;
  }


  acquire();

  // let s = shell.Shell.New();
  let m = machine.Machine.New(selected_mode, is_test);

  // HACK: Taking the address of a reference (`self`) dies
  m.Acquire(&m);

  // Specify the external rendering method
  // m.SetOnRefresh(s.Render);
  // m.SetOnRefresh(render, &s);
  m.SetOnRefresh(render);

  m.Open(input_filename);
  m.Reset();

  let n0 = time.Monotonic();
  let inStop = false;

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

    if is_test {
      if m.CPU.STOP == 1 and not inStop {
        inStop = true;
        n0 = time.Monotonic();
      }

      // TODO: extract this out nicer
      let n1 = time.Monotonic();
      let elapsed = n1.Sub(n0);
      if elapsed.Seconds() > 20 or (inStop and elapsed.Seconds() > 1) {
        // Create surface from GPU frame buffer
        let surface = SDL_CreateRGBSurfaceFrom(
          m.GPU.FrameBuffer as *uint8,
          int32(WIDTH),
          int32(HEIGHT), 32,
          int32(WIDTH * 4),
          0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000);

        let file = SDL_RWFromFile(test_output_filename, "wb");
        SDL_SaveBMP_RW(surface, file, 1);

        break;
      }
    }
  }

  m.Release();
  // s.Release();
  release();
}
