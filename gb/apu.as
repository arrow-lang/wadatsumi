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

struct APU {
  Channel1: channelSquare.ChannelSquare;
  Channel2: channelSquare.ChannelSquare;
  Channel3: channelWave.ChannelWave;
  Channel4: channelNoise.ChannelNoise;

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
  NR50: uint8;

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

    component.Channel1 = channelSquare.ChannelSquare.New(1);
    component.Channel2 = channelSquare.ChannelSquare.New(2);
    // TODO: Channel 3
    // TODO: Channel 4

    return component;
  }

  def Release(self) {
    // TODO: Channel 3
  }

  def Reset(self) {
    self.Channel1.Reset();
    self.Channel2.Reset();
    // TODO: self.Channel3.Reset();
    // TODO: self.Channel4.Reset();

    self.SequencerTimer = 0;
    self.SequencerStep = 0;
    self.SampleTimer = 95;
  }

  def Read(self, address: uint16, ptr: *uint8): bool {
    if self.Channel1.Read(address, ptr) { return true; }
    if self.Channel2.Read(address, ptr) { return true; }

    *ptr = if address == 0xFF25 {
      (
        bits.Bit(self.Channel4REnable, 7) |
        bits.Bit(self.Channel3REnable, 6) |
        bits.Bit(self.Channel2REnable, 5) |
        bits.Bit(self.Channel1REnable, 4) |
        bits.Bit(self.Channel4LEnable, 3) |
        bits.Bit(self.Channel3LEnable, 2) |
        bits.Bit(self.Channel2LEnable, 1) |
        bits.Bit(self.Channel1LEnable, 0)
      );
    } else if address == 0xFF26 {
      (
        bits.Bit(self.Enable, 7) |
        bits.Bit(true, 6) |
        bits.Bit(true, 5) |
        // bits.Bit(self.Channel4.Enable, 3) |
        // bits.Bit(self.Channel3.Enable, 2) |
        bits.Bit(self.Channel2.Enable, 1) |
        bits.Bit(self.Channel1.Enable, 0)
      );
    } else {
      return false;
    };

    return true;
  }

  def Write(self, address: uint16, value: uint8): bool {
    if self.Channel1.Write(address, value) { return true; }
    if self.Channel2.Write(address, value) { return true; }

    if address == 0xFF25 {
      self.Channel4REnable = bits.Test(value, 7);
      self.Channel3REnable = bits.Test(value, 6);
      self.Channel2REnable = bits.Test(value, 5);
      self.Channel1REnable = bits.Test(value, 4);
      self.Channel4LEnable = bits.Test(value, 3);
      self.Channel3LEnable = bits.Test(value, 2);
      self.Channel2LEnable = bits.Test(value, 1);
      self.Channel1LEnable = bits.Test(value, 0);
    } else if address == 0xFF26 {
      self.Enable = bits.Test(value, 7);
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
      // TODO: Channel3
      // TODO: Channel4

      // Tick: frame sequencer
      if self.SequencerTimer > 0 { self.SequencerTimer -= 1; }
      if self.SequencerTimer == 0 {
        // Length counter is updated every other step
        if self.SequencerStep % 2 == 0 {
          self.Channel1.TickLength();
          self.Channel2.TickLength();
          // TODO: Channel4
        }

        // Volume is adjusted every 7th step
        if self.SequencerStep == 7 {
          self.Channel1.TickVolumeEnvelope();
          self.Channel2.TickVolumeEnvelope();
          // TODO: Channel4
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

          if self.Channel1LEnable { sample.L += ch1; }
          if self.Channel2LEnable { sample.L += ch2; }

          if self.Channel1REnable { sample.R += ch1; }
          if self.Channel2REnable { sample.R += ch2; }

          sample.L *= 50;
          sample.R *= 50;

          SDL_QueueAudio(1, &sample as *uint8, 4);
        }

        // Reload sample timer
        self.SampleTimer = 95;
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
