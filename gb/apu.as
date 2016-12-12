import "std";
import "libc";

import "./mmu";
import "./bits";

import "./channelSquare";
import "./channelWave";
import "./channelNoise";

#include "SDL2/SDL.h"

struct Sample {
  // Left output terminal (L)
  L: int16;

  // Right output terminal (R)
  R: int16;
}

// TODO: Make configurable
let BUFFER_SIZE: uint32 = 1024;

// TODO: Make configurable
let SAMPLE_RATE = 96000;

struct APU {
  Channel1: channelSquare.ChannelSquare;
  Channel2: channelSquare.ChannelSquare;
  Channel3: channelWave.ChannelWave;
  Channel4: channelNoise.ChannelNoise;

  Buffer: *Sample;
  BufferIndex: uint32;

  // Sound Control Registers
  // -----------------------

  // Frame sequencer
  SequencerTimer: uint16;
  SequencerStep: uint8;

  // Sample timer (<hz> / <sample_rate>)
  SampleTimer: uint16;

  // FF24 - NR50 - Channel control / ON-OFF / Volume (R/W)
  //    Bit 7   - Output Vin to SO2 terminal (1=Enable)
  //    Bit 6-4 - SO2 output level (volume)  (0-7)
  //    Bit 3   - Output Vin to SO1 terminal (1=Enable)
  //    Bit 2-0 - SO1 output level (volume)  (0-7)
  // L = SO2
  // R = SO1
  VinL: bool;
  VolumeL: uint8;
  VinR: bool;
  VolumeR: uint8;

  // FF25 - NR51 - Selection of Sound output terminal (R/W)
  //    Bit 7 - Output sound 4 to SO2 terminal
  //    Bit 6 - Output sound 3 to SO2 terminal
  //    Bit 5 - Output sound 2 to SO2 terminal
  //    Bit 4 - Output sound 1 to SO2 terminal
  //    Bit 3 - Output sound 4 to SO1 terminal
  //    Bit 2 - Output sound 3 to SO1 terminal
  //    Bit 1 - Output sound 2 to SO1 terminal
  //    Bit 0 - Output sound 1 to SO1 terminal
  Channel4REnable: bool;
  Channel3REnable: bool;
  Channel2REnable: bool;
  Channel1REnable: bool;
  Channel4LEnable: bool;
  Channel3LEnable: bool;
  Channel2LEnable: bool;
  Channel1LEnable: bool;

  // FF26 - NR52 - Sound on/off
  //    Bit 7 - All sound on/off  (0: stop all sound circuits) (Read/Write)
  //    Bit 3 - Sound 4 ON flag (Read Only)
  //    Bit 2 - Sound 3 ON flag (Read Only)
  //    Bit 1 - Sound 2 ON flag (Read Only)
  //    Bit 0 - Sound 1 ON flag (Read Only)
  Enable: bool;
}

implement APU {
  def New(): Self {
    let component: APU;
    libc.memset(&component as *uint8, 0, std.size_of<APU>());

    component.Buffer = libc.malloc(uint64(BUFFER_SIZE * 4)) as *Sample;
    component.BufferIndex = 0;

    return component;
  }

  def Acquire(self, this: *APU) {
    self.Channel1 = channelSquare.ChannelSquare.New(1, this);
    self.Channel2 = channelSquare.ChannelSquare.New(2, this);
    self.Channel3 = channelWave.ChannelWave.New(this);
    self.Channel4 = channelNoise.ChannelNoise.New(this);
  }

  def Release(self) {
    libc.free(self.Buffer as *uint8);
    self.Channel3.Release();
  }

  def Reset(self) {
    self.Enable = false;

    libc.memset(self.Buffer as *uint8, 0, uint64(BUFFER_SIZE) * 4);
    self.BufferIndex = 0;

    self.Channel1.Reset();
    self.Channel2.Reset();
    self.Channel3.Reset();
    self.Channel4.Reset();

    self.VinL = false;
    self.VinR = false;

    self.SequencerTimer = 8192;
    self.SequencerStep = 0;
    self.SampleTimer = 4194304 / 48000;

    self.Channel4REnable = false;
    self.Channel3REnable = false;
    self.Channel2REnable = false;
    self.Channel1REnable = false;
    self.Channel4LEnable = false;
    self.Channel3LEnable = false;
    self.Channel2LEnable = false;
    self.Channel1LEnable = false;

    self.VinL = false;
    self.VolumeL = 0;
    self.VinR = false;
    self.VolumeR = 0;
  }

  def Read(self, address: uint16, ptr: *uint8): bool {
    if self.Channel1.Read(address, ptr) { return true; }
    if self.Channel2.Read(address, ptr) { return true; }
    if self.Channel3.Read(address, ptr) { return true; }
    if self.Channel4.Read(address, ptr) { return true; }

    *ptr = if address == 0xFF24 {
      (
        bits.Bit(self.VinL, 7) |
        (self.VolumeL << 4) |
        bits.Bit(self.VinR, 3) |
        (self.VolumeR)
      );
    } else if address == 0xFF25 {
      (
        bits.Bit(self.Channel4LEnable, 7) |
        bits.Bit(self.Channel3LEnable, 6) |
        bits.Bit(self.Channel2LEnable, 5) |
        bits.Bit(self.Channel1LEnable, 4) |
        bits.Bit(self.Channel4REnable, 3) |
        bits.Bit(self.Channel3REnable, 2) |
        bits.Bit(self.Channel2REnable, 1) |
        bits.Bit(self.Channel1REnable, 0)
      );
    } else if address == 0xFF26 {
      *ptr = (
        bits.Bit(self.Enable, 7) |
        bits.Bit(true, 6) |
        bits.Bit(true, 5) |
        bits.Bit(true, 4) |
        bits.Bit(self.Channel4.Enable, 3) |
        bits.Bit(self.Channel3.Enable, 2) |
        bits.Bit(self.Channel2.Enable, 1) |
        bits.Bit(self.Channel1.Enable, 0)
      );

      return true;
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if self.Channel1.Write(address, value) { return true; }
    if self.Channel2.Write(address, value) { return true; }
    if self.Channel3.Write(address, value) { return true; }
    if self.Channel4.Write(address, value) { return true; }

    if address == 0xFF26 {
      if self.Enable and not bits.Test(value, 7) {
        // Disabling sound soft-resets the APU
        self.Reset();
      } else if not self.Enable and bits.Test(value, 7) {
        self.Enable = true;

        // When powered on, the frame sequencer is reset so that the
        // next step will be 0
        self.SequencerStep = 0;

        // The square duty units are reset to the first step of the waveform,
        self.Channel1.DutyPosition = 0;
        self.Channel2.DutyPosition = 0;

        // and the wave channel's sample buffer is reset to 0.
        self.Channel3.Buffer = 0;
      }

      return true;
    }

    // If master is disabled; leave unhandled
    if not self.Enable { return false; }

    if address == 0xFF24 {
      self.VinL = bits.Test(value, 7);
      self.VolumeL = (value >> 4) & 0b111;
      self.VinR = bits.Test(value, 3);
      self.VolumeR = value & 0b111;
    } else if address == 0xFF25 {
      self.Channel4LEnable = bits.Test(value, 7);
      self.Channel3LEnable = bits.Test(value, 6);
      self.Channel2LEnable = bits.Test(value, 5);
      self.Channel1LEnable = bits.Test(value, 4);
      self.Channel4REnable = bits.Test(value, 3);
      self.Channel3REnable = bits.Test(value, 2);
      self.Channel2REnable = bits.Test(value, 1);
      self.Channel1REnable = bits.Test(value, 0);
    } else {
      return false;
    }

    return true;
  }

  def Tick(self) {
    let n = 0;
    while n < 4 {
      // Tick: channels
      self.Channel1.Tick();
      self.Channel2.Tick();
      self.Channel3.Tick();
      self.Channel4.Tick();

      // Tick: frame sequencer
      if self.SequencerTimer > 0 { self.SequencerTimer -= 1; }
      if self.SequencerTimer == 0 {
        // Length counter is updated every other step
        if self.SequencerStep % 2 == 0 {
          self.Channel1.TickLength();
          self.Channel2.TickLength();
          self.Channel3.TickLength();
          self.Channel4.TickLength();
        }

        // Volume is adjusted every 7th step
        if self.SequencerStep == 7 {
          self.Channel1.TickVolumeEnvelope();
          self.Channel2.TickVolumeEnvelope();
          self.Channel4.TickVolumeEnvelope();
        }

        // Sweep is adjusted every 2nd and 6th steps
        if self.SequencerStep == 2 or self.SequencerStep == 6 {
          self.Channel1.TickSweep();
        }

        // Step the sequencer
        self.SequencerStep += 1;
        if self.SequencerStep == 8 { self.SequencerStep = 0; }

        // Reload sequencer timer
        self.SequencerTimer = 8192;
      }

      // Sample
      if self.SampleTimer > 0 { self.SampleTimer -= 1; }
      if self.SampleTimer == 0 {
        let sample: Sample;
        sample.L = 0;
        sample.R = 0;

        if self.Enable {
          let ch1 = self.Channel1.Sample();
          let ch2 = self.Channel2.Sample();
          let ch3 = self.Channel3.Sample();
          let ch4 = self.Channel4.Sample();

          if self.Channel1LEnable { sample.L += ch1; }
          if self.Channel2LEnable { sample.L += ch2; }
          if self.Channel3LEnable { sample.L += ch3; }
          if self.Channel4LEnable { sample.L += ch4; }

          if self.Channel1REnable { sample.R += ch1; }
          if self.Channel2REnable { sample.R += ch2; }
          if self.Channel3REnable { sample.R += ch3; }
          if self.Channel4REnable { sample.R += ch4; }
        }

        sample.L *= int16(self.VolumeL) * 8;
        sample.R *= int16(self.VolumeR) * 8;

        *(self.Buffer + self.BufferIndex) = sample;
        self.BufferIndex += 1;

        if self.BufferIndex >= BUFFER_SIZE {
          self.BufferIndex = 0;

          // FIXME: Move to shell (SDL shouldn't be in here)

          // Drain audio buffer
          while SDL_GetQueuedAudioSize(1) > (BUFFER_SIZE * 4) {
            SDL_Delay(1);
          }

          SDL_QueueAudio(1, self.Buffer as *uint8, (BUFFER_SIZE * 4));
        }

        // Reload sample timer
        self.SampleTimer = uint16(4194304 / SAMPLE_RATE);
      }

      n += 1;
    }
  }

  def AsMemoryController(self, this: *APU): mmu.MemoryController {
    let mc: mmu.MemoryController;
    mc.Read = MCRead;
    mc.Write = MCWrite;
    mc.Data = this as *uint8;
    mc.Release = MCRelease;

    return mc;
  }
}

def MCRelease(this: *mmu.MemoryController) {
  // Do nothing
}

def MCRead(this: *mmu.MemoryController, address: uint16, value: *uint8): bool {
  return (this.Data as *APU).Read(address, value);
}

def MCWrite(this: *mmu.MemoryController, address: uint16, value: uint8): bool {
  return (this.Data as *APU).Write(address, value);
}
