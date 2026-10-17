const std = @import("std");
const wavetable = @import("wavetable.zig");
const filter = @import("filter.zig");
const shaper = @import("shaper.zig");
const envelope = @import("envelope.zig");
const lfo = @import("lfo.zig");
const sub = @import("sub.zig");

pub const VECTOR_SIZE = wavetable.VECTOR_SIZE;
pub const FloatVec = wavetable.FloatVec;

pub const Voice = struct {
    osc: wavetable.WavetableOsc,
    flt: filter.SvfFilter,
    dst: shaper.AsymmetricShaper,
    env: envelope.AdsrEnvelope,
    synth_lfo: lfo.Lfo,
    sub_osc: sub.SubOsc,

    base_cutoff: f32,
    env_amount: f32,
    base_morph: f32,
    lfo_morph_amount: f32,

    pub fn initInto(self: *Voice, sample_rate: f32) void {
        self.osc.initInto(55.0, sample_rate);
        self.flt = filter.SvfFilter.init(sample_rate);
        self.dst = shaper.AsymmetricShaper.init();
        self.env = envelope.AdsrEnvelope.init(sample_rate);
        self.synth_lfo = lfo.Lfo.init(sample_rate);
        self.sub_osc = sub.SubOsc.init();

        self.base_cutoff = 120.0;
        self.env_amount = 0.0;
        self.base_morph = 0.0;
        self.lfo_morph_amount = 0.5;
    }

    pub fn setFrequency(self: *Voice, freq: f32) void {
        self.osc.setFrequency(freq);
    }
    pub fn setMorph(self: *Voice, pos: f32) void {
        self.base_morph = std.math.clamp(pos, 0.0, 15.0);
        self.osc.setMorphPosition(self.base_morph);
    }
    pub fn setCutoff(self: *Voice, cutoff: f32) void {
        self.base_cutoff = cutoff;
    }
    pub fn setResonance(self: *Voice, res: f32) void {
        self.flt.setResonance(res);
    }
    pub fn setFilterDrive(self: *Voice, drive: f32) void {
        self.flt.setDrive(drive);
    }
    pub fn setFilterMode(self: *Voice, mode: filter.FilterMode) void {
        self.flt.setMode(mode);
    }
    pub fn setShaperDrive(self: *Voice, drive: f32) void {
        self.dst.setDrive(drive);
    }
    pub fn setShaperAsymmetry(self: *Voice, asym: f32) void {
        self.dst.setAsymmetry(asym);
    }
    pub fn setLfoRate(self: *Voice, freq: f32) void {
        self.synth_lfo.setFrequency(freq);
    }
    pub fn setLfoShape(self: *Voice, shape: lfo.LfoShape) void {
        self.synth_lfo.setShape(shape);
    }
    pub fn setEnvAmount(self: *Voice, amount: f32) void {
        self.env_amount = amount;
    }

    pub fn setChorusRate(self: *Voice, rate: f32) void {
        self.osc.setChorusRate(rate);
    }
    pub fn setChorusDepth(self: *Voice, depth: f32) void {
        self.osc.setChorusDepth(depth);
    }
    pub fn setChorusFeedback(self: *Voice, feedback: f32) void {
        self.osc.setChorusFeedback(feedback);
    }
    pub fn setChorusMix(self: *Voice, mix: f32) void {
        self.osc.setChorusMix(mix);
    }
    pub fn setChorusFilterCutoff(self: *Voice, cutoff: f32) void {
        self.osc.setChorusFilterCutoff(cutoff);
    }
    pub fn setChorusEnabled(self: *Voice, enabled: bool) void {
        self.osc.enableChorus(enabled);
    }

    pub fn noteOn(self: *Voice, velocity: f32) void {
        self.env.triggerOn(velocity);
        self.synth_lfo.reset();
        self.sub_osc.reset();
    }

    pub fn noteOff(self: *Voice) void {
        self.env.triggerOff();
    }

    pub fn processBlock(self: *Voice, out_buffer: []f32) void {
        var osc_out_arr: [VECTOR_SIZE]f32 = undefined;
        self.osc.process_block(&osc_out_arr);
        const raw_vector = @as(FloatVec, osc_out_arr);

        var lfo_vec: [VECTOR_SIZE]f32 = undefined;
        var env_vec: [VECTOR_SIZE]f32 = undefined;

        inline for (0..VECTOR_SIZE) |i| {
            lfo_vec[i] = self.synth_lfo.process();
            env_vec[i] = self.env.process();
        }

        var filtered_arr: [VECTOR_SIZE]f32 = undefined;
        inline for (0..VECTOR_SIZE) |i| {
            const modulated_cutoff = std.math.clamp(self.base_cutoff + (env_vec[i] * self.env_amount), 20.0, 20000.0);
            self.flt.setCutoff(modulated_cutoff);

            const sub_sample = self.sub_osc.process(self.osc.phase_step[i]);
            const mixed_sample = raw_vector[i] + sub_sample;

            const single_sample: FloatVec = @splat(mixed_sample);
            const filtered_sample = self.flt.process_vector(single_sample);
            filtered_arr[i] = filtered_sample[0];
        }
        const filtered_vector = @as(FloatVec, filtered_arr);

        const shaped_vector = self.dst.process_vector(filtered_vector);
        const env_vector = @as(FloatVec, env_vec);
        const final_vector = shaped_vector * env_vector;

        inline for (0..VECTOR_SIZE) |i| {
            out_buffer[i] = final_vector[i];
        }
    }

    pub fn isIdle(self: *Voice) bool {
        return self.env.state == .idle;
    }
};
