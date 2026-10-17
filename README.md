# RuneDSP

A polyphonic synthesizer engine I'm building in Rust + Zig. It runs as a CLAP/VST3 plugin inside DAWs like Reaper.

**Status: Active development.** Things work, things break, I'm learning. Expect rough edges.

---

## What it does

You send it MIDI notes, it gives you sound. Under the hood it's doing SIMD-vectorized DSP (8 samples at a time), polyphonic voice management, filtering, shaping, chorus, sub-oscillator, and a basic stereo reverb.

I started this because I wanted to understand how synthesizers actually work — not just turn knobs in Serum, but write the math myself. Then it got out of hand and now it's a real plugin.

---

## What works right now

- **8-voice polyphony** with voice stealing (steals the oldest voice when you run out)
- **Wavetable oscillator** with morph between 16 waveforms
- **TPT state-variable filter** (lowpass/bandpass/highpass) with resonance and drive — based on Andrew Simper's Cytomic paper
- **Asymmetric waveshaper** for distortion
- **ADSR envelope** with multiple curve shapes (linear, exponential, logarithmic, S-curve)
- **LFO** modulating wavetable morph
- **Stereo chorus** with filter and feedback
- **Sub-oscillator** (-1 or -2 octaves, sine/triangle/square)
- **Stereo reverb** — basic feedback delay line with damping. It sounds okay, not amazing
- **Rust ↔ Zig FFI** — Rust handles the plugin host (nih-plug), Zig handles the DSP. They talk over `extern "C"` functions

---

## What's still broken or missing

- **No anti-aliasing** on the oscillator. High notes alias and sound gritty. Need to implement BLEP/MinBLEP
- **Reverb is naive** — single delay line, not a proper FDN or Schroeder. Sounds like a small room, not a hall
- **No unison/detune** — can't do fat supersaw sounds yet
- **No modulation matrix** — LFO only modulates morph right now. Should be able to modulate cutoff, pitch, reverb mix, etc.
- **No GUI** — you use the DAW's default parameter list. Planning to build one with egui
- **JACK sometimes hangs** — still debugging buffer handling in the FFI layer. Works fine with ALSA
- **Probably memory leaks** somewhere in the voice allocator. Haven't run valgrind yet

---

## Why Rust + Zig

Short version: I wanted to learn both, and this project gave me a reason.

Longer version: Rust (via `nih-plug`) handles the plugin lifecycle, parameter management, and MIDI. It's safe and the ecosystem is great. Zig handles the hot DSP loop — no allocator in the audio thread, explicit SIMD with `@Vector(8, f32)`, and it compiles fast. The FFI between them is just plain C functions, no magic.

Could I have done it all in Rust? Yes. Would it be faster? Probably not noticeably. But writing the DSP in Zig taught me more about memory layout and cache behavior than any tutorial.

---

## How to build it

### Clone
git clone https://github.com/ValkyrieSentinel/runedsp.git
cd runedsp

### Build
*(needs Rust nightly + Zig installed)*

cargo build --release

### Install as CLAP plugin (Linux)
cp target/release/librunedsp.so ~/.clap/runedsp.clap
chmod +x ~/.clap/runedsp.clap

### How to use
Open Reaper, add it to a track, send it MIDI.

If it crashes on load, that's probably my FFI buffer handling. Try running Reaper from a terminal and check /tmp/runedsp_debug.log.

---

## Architecture (the short version)

```text

Reaper (host)
  ↓ MIDI + audio buffers
Rust (nih-plug)
  ↓ extern "C" calls
Zig lib.zig (FFI layer, owns the PolyEngine on the heap)
  ↓
Zig poly.zig (8 voices, mixes them, runs reverb)
  ↓
Zig engine.zig (per-voice: osc → filter → shaper → envelope)
  ↓
Zig wavetable.zig, filter.zig, shaper.zig, etc.
  ↓
Speakers (hopefully)

The PolyEngine is heap-allocated in runedsp_init and passed around as an opaque pointer. No allocations happen in the audio thread — that was a hard lesson learned early.

---

## What's next

- BLEP oscillator (fix the aliasing)
- Proper FDN reverb (8+ delay lines)
- Unison mode (stack 4-8 detuned voices per note)
- Modulation matrix
- egui-based GUI
- Maybe port to Windows/macOS if anyone asks

---

## License

MIT. Do whatever you want with it. If you use it in something cool, let me know — I'd love to hear about it!
