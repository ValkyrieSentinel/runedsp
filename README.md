# RuneDSP

> ⚠️ **STATUS: ACTIVE DEVELOPMENT**  
> This project is under active development. Things work, things break, I'm learning. Expect rough edges.

A polyphonic synthesizer engine I'm building in Rust + Zig. It runs as a CLAP/VST3 plugin inside DAWs like Reaper.

---

## What it does

You send it MIDI notes, it gives you sound. Under the hood it's doing SIMD-vectorized DSP (8 samples at a time), polyphonic voice management, filtering, shaping, chorus, sub-oscillator, and a basic stereo reverb.

I started this because I wanted to understand how synthesizers actually work — not just turn knobs in Serum, but write the math myself. Then it got out of hand and now it's a real plugin.

---

## What works right now

- **8-voice polyphony** with voice stealing
- **Wavetable oscillator** with morph between 16 waveforms
- **TPT state-variable filter** (lowpass/bandpass/highpass)
- **Asymmetric waveshaper** for distortion
- **ADSR envelope** with multiple curve shapes
- **LFO** modulating wavetable morph
- **Stereo chorus** with filter and feedback
- **Sub-oscillator** (-1 or -2 octaves)
- **Stereo reverb** with damping
- **Rust ↔ Zig FFI** via nih-plug

---

## What's still broken

- No anti-aliasing (high notes alias)
- Reverb is naive (single delay line)
- No unison/detune
- No modulation matrix
- No GUI
- JACK sometimes hangs
- Probably memory leaks

---

## Why Rust + Zig

Rust handles plugin lifecycle and MIDI. Zig handles the hot DSP loop with SIMD. FFI is plain C functions.

---

## How to build

```bash
git clone https://github.com/ValkyrieSentinel/runedsp.git
cd runedsp
cargo build --release
cp target/release/librunedsp.so ~/.clap/runedsp.clap
chmod +x ~/.clap/runedsp.clap
```

---

## Architecture

```text
Reaper → Rust (nih-plug) → Zig (lib.zig) → Zig (poly.zig) → Zig (engine.zig) → Speakers
```

---

## What's next

1. BLEP oscillator
2. FDN reverb
3. Unison mode
4. Modulation matrix
5. egui GUI

---

## License

MIT.

---


