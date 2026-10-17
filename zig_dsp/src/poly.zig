const std = @import("std");
const engine = @import("engine.zig");
const Reverb = @import("reverb.zig").StereoReverb;

pub const MAX_VOICES = 8;
pub const VECTOR_SIZE = engine.VECTOR_SIZE;

pub const PolyEngine = struct {
    voices: [MAX_VOICES]VoiceSlot,
    sample_rate: f32,
    age_counter: u64,
    master_saturation: f32,
    master_makeup_gain: f32,
    reverb: Reverb,

    const VoiceSlot = struct {
        voice: engine.Voice,
        note: u8,
        active: bool,
        age: u64,
    };

    pub fn initInto(self: *PolyEngine, sample_rate: f32) void {
        self.sample_rate = sample_rate;
        self.age_counter = 0;
        self.master_saturation = 1.0;
        self.master_makeup_gain = 0.85;
        self.reverb = Reverb.init();

        for (&self.voices) |*slot| {
            slot.voice.initInto(sample_rate);
            slot.note = 0;
            slot.active = false;
            slot.age = 0;
        }
    }

    pub fn setCutoff(self: *PolyEngine, cutoff: f32) void {
        for (&self.voices) |*slot| slot.voice.setCutoff(cutoff);
    }
    pub fn setResonance(self: *PolyEngine, res: f32) void {
        for (&self.voices) |*slot| slot.voice.setResonance(res);
    }
    pub fn setFilterDrive(self: *PolyEngine, drive: f32) void {
        for (&self.voices) |*slot| slot.voice.setFilterDrive(drive);
    }
    pub fn setShaperDrive(self: *PolyEngine, drive: f32) void {
        for (&self.voices) |*slot| slot.voice.setShaperDrive(drive);
    }
    pub fn setShaperAsymmetry(self: *PolyEngine, asym: f32) void {
        for (&self.voices) |*slot| slot.voice.setShaperAsymmetry(asym);
    }
    pub fn setMorph(self: *PolyEngine, pos: f32) void {
        for (&self.voices) |*slot| slot.voice.setMorph(pos);
    }
    pub fn setLfoRate(self: *PolyEngine, freq: f32) void {
        for (&self.voices) |*slot| slot.voice.setLfoRate(freq);
    }
    pub fn setEnvAmount(self: *PolyEngine, amount: f32) void {
        for (&self.voices) |*slot| slot.voice.setEnvAmount(amount);
    }
    pub fn setMasterSaturation(self: *PolyEngine, drive: f32) void {
        self.master_saturation = std.math.clamp(drive, 1.0, 4.0);
    }
    pub fn setMasterMakeupGain(self: *PolyEngine, gain: f32) void {
        self.master_makeup_gain = std.math.clamp(gain, 0.1, 1.0);
    }

    pub fn setReverbMix(self: *PolyEngine, mix: f32) void {
        self.reverb.mix = std.math.clamp(mix, 0.0, 1.0);
    }
    pub fn setReverbFeedback(self: *PolyEngine, fb: f32) void {
        self.reverb.feedback = std.math.clamp(fb, 0.1, 0.85);
    }
    pub fn setReverbDamp(self: *PolyEngine, damp: f32) void {
        self.reverb.damp = std.math.clamp(damp, 0.1, 0.9);
    }

    pub fn noteOn(self: *PolyEngine, note: u8, velocity: f32) void {
        for (&self.voices) |*slot| {
            if (slot.active and slot.note == note) {
                slot.voice.noteOn(velocity);
                slot.age = self.age_counter;
                self.age_counter += 1;
                return;
            }
        }

        for (&self.voices) |*slot| {
            if (!slot.active) {
                slot.note = note;
                slot.active = true;
                slot.age = self.age_counter;
                self.age_counter += 1;
                slot.voice.setFrequency(midiToFreq(note));
                slot.voice.noteOn(velocity);
                return;
            }
        }

        var oldest_idx: usize = 0;
        var oldest_age = self.voices[0].age;
        for (&self.voices, 0..) |*slot, i| {
            if (slot.age < oldest_age) {
                oldest_age = slot.age;
                oldest_idx = i;
            }
        }

        const steal_slot = &self.voices[oldest_idx];
        steal_slot.note = note;
        steal_slot.active = true;
        steal_slot.age = self.age_counter;
        self.age_counter += 1;
        steal_slot.voice.setFrequency(midiToFreq(note));
        steal_slot.voice.noteOn(velocity);
    }

    pub fn noteOff(self: *PolyEngine, note: u8) void {
        for (&self.voices) |*slot| {
            if (slot.active and slot.note == note) {
                slot.voice.noteOff();
            }
        }
    }

    pub fn processBlock(self: *PolyEngine, out_interleaved: []f32) void {
        var mono_sum: [VECTOR_SIZE]f32 = undefined;
        @memset(&mono_sum, 0.0);

        var temp_buffer: [VECTOR_SIZE]f32 = undefined;

        for (&self.voices) |*slot| {
            if (!slot.active) continue;

            slot.voice.processBlock(&temp_buffer);

            if (slot.voice.isIdle()) {
                slot.active = false;
                continue;
            }

            inline for (0..VECTOR_SIZE) |i| {
                mono_sum[i] += temp_buffer[i];
            }
        }

        inline for (0..VECTOR_SIZE) |i| {
            const driven = mono_sum[i] * self.master_saturation;
            mono_sum[i] = std.math.tanh(driven) * self.master_makeup_gain;
        }

        inline for (0..VECTOR_SIZE) |i| {
            const mono_in = mono_sum[i];

            const stereo_out = self.reverb.process(mono_in, mono_in);

            out_interleaved[i * 2] = stereo_out[0];
            out_interleaved[i * 2 + 1] = stereo_out[1];
        }
    }

    fn midiToFreq(note: u8) f32 {
        const midi_float = @as(f32, @floatFromInt(note));
        return 440.0 * std.math.exp2((midi_float - 69.0) / 12.0);
    }
};
