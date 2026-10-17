const std = @import("std");

pub const VECTOR_SIZE = 8;
pub const FloatVec = @Vector(VECTOR_SIZE, f32);
pub const IntVec = @Vector(VECTOR_SIZE, i32);

pub const TABLE_SIZE = 2048;
pub const TABLE_MASK = TABLE_SIZE - 1;
pub const NUM_TABLES = 16;
pub const MIP_LEVELS = 8;

pub const CHORUS_DELAY_SIZE = 2048;

const MIP_FREQS = [MIP_LEVELS]f32{
    32.70, 65.41, 130.81, 261.63, 523.25, 1046.50, 2093.00, 4186.01,
};

pub const WavetableOsc = struct {
    sample_rate: f32,
    phase: FloatVec,
    phase_step: FloatVec,
    morph_pos: f32,
    current_mip: usize,
    tables: [MIP_LEVELS][NUM_TABLES][TABLE_SIZE]f32,

    chorus_enabled: bool,
    chorus_rate: f32,
    chorus_depth: f32,
    chorus_feedback: f32,
    chorus_mix: f32,
    chorus_filter_cutoff: f32,
    chorus_lfo_phase: [4]f32,
    chorus_lfo_increment: f32,
    chorus_delay_buffer: [4][CHORUS_DELAY_SIZE]f32,
    chorus_delay_write_pos: [4]usize,
    chorus_feedback_filter_state: [4]f32,

    pub fn initInto(self: *WavetableOsc, base_freq: f32, sample_rate: f32) void {
        self.sample_rate = sample_rate;
        self.phase = @splat(0.0);
        self.phase_step = @splat(0.0);
        self.morph_pos = 0.0;
        self.current_mip = 0;
        self.tables = undefined;

        self.chorus_enabled = true;
        self.chorus_rate = 0.3;
        self.chorus_depth = 0.012;
        self.chorus_feedback = 0.35;
        self.chorus_mix = 0.5;
        self.chorus_filter_cutoff = 3000.0;
        self.chorus_lfo_phase = [_]f32{ 0.0, 0.25, 0.5, 0.75 };
        self.chorus_lfo_increment = 0.0;
        self.chorus_delay_write_pos = [_]usize{ 0, 0, 0, 0 };
        self.chorus_feedback_filter_state = [_]f32{ 0.0, 0.0, 0.0, 0.0 };

        for (&self.chorus_delay_buffer) |*buf| {
            @memset(buf, 0.0);
        }

        self.buildWavetables();
        self.setFrequency(base_freq);
    }

    fn buildWavetables(self: *WavetableOsc) void {
        for (&self.tables, 0..) |*mip_tables, mip_idx| {
            const base_freq = MIP_FREQS[mip_idx];
            const nyquist = self.sample_rate / 2.0;
            const max_harmonics = @as(usize, @intFromFloat(@floor(nyquist / base_freq)));
            const clamped_harmonics = @min(max_harmonics, 64);

            for (mip_tables, 0..) |*table, t_idx| {
                const morph_factor = @as(f32, @floatFromInt(t_idx)) / @as(f32, NUM_TABLES - 1);

                for (table, 0..) |*v, i| {
                    const phase_val = @as(f32, @floatFromInt(i)) / @as(f32, TABLE_SIZE) * std.math.tau;
                    var sample: f32 = 0.0;

                    var h: usize = 1;
                    while (h <= clamped_harmonics) : (h += 1) {
                        const h_f = @as(f32, @floatFromInt(h));
                        const saw_amp = 1.0 / h_f;
                        const active_amp = if (h == 1) 1.0 else saw_amp * morph_factor;
                        sample += active_amp * @sin(phase_val * h_f);
                    }
                    v.* = sample;
                }

                var max_val: f32 = 0.0;
                for (table) |v| {
                    max_val = @max(max_val, @abs(v));
                }
                if (max_val > 0.0) {
                    const norm_factor = 1.0 / max_val;
                    for (table) |*v| {
                        v.* *= norm_factor;
                    }
                }
            }
        }
    }

    fn getMipLevel(freq: f32) usize {
        for (MIP_FREQS, 0..) |mip_freq, level| {
            if (freq <= mip_freq) return level;
        }
        return MIP_LEVELS - 1;
    }

    pub fn setFrequency(self: *WavetableOsc, base_freq: f32) void {
        self.current_mip = getMipLevel(base_freq);

        var steps_arr: [VECTOR_SIZE]f32 = undefined;
        inline for (0..VECTOR_SIZE) |i| {
            const detune = 1.0 + (@as(f32, @floatFromInt(i)) - 3.5) * 0.0015;
            steps_arr[i] = (base_freq * detune) / self.sample_rate;
        }
        self.phase_step = @as(FloatVec, steps_arr);
    }

    pub fn setMorphPosition(self: *WavetableOsc, pos: f32) void {
        self.morph_pos = std.math.clamp(pos, 0.0, @as(f32, NUM_TABLES - 1.001));
    }

    pub fn setChorusRate(self: *WavetableOsc, rate: f32) void {
        self.chorus_rate = std.math.clamp(rate, 0.05, 3.0);
        self.updateChorusLfoIncrement();
    }

    pub fn setChorusDepth(self: *WavetableOsc, depth_ms: f32) void {
        self.chorus_depth = std.math.clamp(depth_ms, 0.005, 0.025);
    }

    pub fn setChorusFeedback(self: *WavetableOsc, feedback: f32) void {
        self.chorus_feedback = std.math.clamp(feedback, 0.0, 0.6);
    }

    pub fn setChorusMix(self: *WavetableOsc, mix: f32) void {
        self.chorus_mix = std.math.clamp(mix, 0.0, 1.0);
    }

    pub fn setChorusFilterCutoff(self: *WavetableOsc, cutoff: f32) void {
        self.chorus_filter_cutoff = std.math.clamp(cutoff, 500.0, 8000.0);
    }

    pub fn enableChorus(self: *WavetableOsc, enabled: bool) void {
        self.chorus_enabled = enabled;
    }

    fn updateChorusLfoIncrement(self: *WavetableOsc) void {
        self.chorus_lfo_increment = self.chorus_rate / self.sample_rate;
    }

    fn cubicInterpolate(y0: f32, y1: f32, y2: f32, y3: f32, frac: f32) f32 {
        const c0 = y1;
        const c1 = 0.5 * (y2 - y0);
        const c2 = y0 - 2.5 * y1 + 2.0 * y2 - 0.5 * y3;
        const c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2);
        return ((c3 * frac + c2) * frac + c1) * frac + c0;
    }

    fn readChorusDelay(self: *WavetableOsc, voice: usize, delay_samples: f32) f32 {
        const buf = &self.chorus_delay_buffer[voice];
        const write_pos = self.chorus_delay_write_pos[voice];

        var read_pos_f = @as(f32, @floatFromInt(write_pos)) - delay_samples;
        if (read_pos_f < 0.0) {
            read_pos_f += @as(f32, @floatFromInt(CHORUS_DELAY_SIZE));
        }

        const read_pos_int = @as(usize, @intFromFloat(read_pos_f));
        const frac = read_pos_f - @as(f32, @floatFromInt(read_pos_int));

        const idx0 = (read_pos_int + CHORUS_DELAY_SIZE - 1) % CHORUS_DELAY_SIZE;
        const idx1 = read_pos_int % CHORUS_DELAY_SIZE;
        const idx2 = (read_pos_int + 1) % CHORUS_DELAY_SIZE;
        const idx3 = (read_pos_int + 2) % CHORUS_DELAY_SIZE;

        return cubicInterpolate(buf[idx0], buf[idx1], buf[idx2], buf[idx3], frac);
    }

    fn applyChorusFeedbackFilter(self: *WavetableOsc, voice: usize, input: f32) f32 {
        const a = 1.0 - @exp(-2.0 * std.math.pi * self.chorus_filter_cutoff / self.sample_rate);
        self.chorus_feedback_filter_state[voice] += a * (input - self.chorus_feedback_filter_state[voice]);
        return self.chorus_feedback_filter_state[voice];
    }

    fn getChorusLfoValue(self: *WavetableOsc, voice: usize) f32 {
        const phase = self.chorus_lfo_phase[voice];
        const val = @sin(phase * 2.0 * std.math.pi);

        self.chorus_lfo_phase[voice] += self.chorus_lfo_increment;
        if (self.chorus_lfo_phase[voice] >= 1.0) {
            self.chorus_lfo_phase[voice] -= 1.0;
        }

        return val;
    }

    fn readWavetable(self: *WavetableOsc, mip: usize, morph: f32, phase_val: f32) f32 {
        const table_idx = phase_val * @as(f32, TABLE_SIZE);
        const idx0 = @as(usize, @intFromFloat(table_idx)) & TABLE_MASK;
        const idx1 = (idx0 + 1) & TABLE_MASK;
        const frac = table_idx - @as(f32, @floatFromInt(idx0));

        const t_idx0 = @as(usize, @intFromFloat(morph));
        const t_idx1 = @min(t_idx0 + 1, NUM_TABLES - 1);
        const frac_morph = morph - @as(f32, @floatFromInt(t_idx0));

        const table_a = &self.tables[mip][t_idx0];
        const table_b = &self.tables[mip][t_idx1];

        const s0_a = table_a[idx0];
        const s1_a = table_a[idx1];
        const val_a = s0_a + (s1_a - s0_a) * frac;

        const s0_b = table_b[idx0];
        const s1_b = table_b[idx1];
        const val_b = s0_b + (s1_b - s0_b) * frac;

        return val_a + (val_b - val_a) * frac_morph;
    }

    fn processOscSample(self: *WavetableOsc, phase_val: f32) f32 {
        return self.readWavetable(self.current_mip, self.morph_pos, phase_val);
    }

    fn processChorusSample(self: *WavetableOsc, input: f32) f32 {
        if (!self.chorus_enabled) return input;

        var wet_sum: f32 = 0.0;
        const base_delay: f32 = 0.015 * self.sample_rate;
        const depth_samples: f32 = self.chorus_depth * self.sample_rate;

        for (0..4) |voice| {
            const lfo_val = self.getChorusLfoValue(voice);
            const modulated_delay = base_delay + lfo_val * depth_samples;

            const delayed = self.readChorusDelay(voice, modulated_delay);
            const feedback_signal = self.applyChorusFeedbackFilter(voice, delayed);

            const write_signal = input + feedback_signal * self.chorus_feedback;
            self.chorus_delay_buffer[voice][self.chorus_delay_write_pos[voice]] = write_signal;

            wet_sum += delayed;
        }

        for (0..4) |voice| {
            self.chorus_delay_write_pos[voice] = (self.chorus_delay_write_pos[voice] + 1) % CHORUS_DELAY_SIZE;
        }

        const wet = wet_sum / 4.0;
        return input * (1.0 - self.chorus_mix) + wet * self.chorus_mix;
    }

    pub fn process_block(self: *WavetableOsc, out_buffer: []f32) void {
        var samples_arr: [VECTOR_SIZE]f32 = undefined;

        inline for (0..VECTOR_SIZE) |i| {
            const osc_sample = self.processOscSample(self.phase[i]);
            const final_sample = self.processChorusSample(osc_sample);
            samples_arr[i] = final_sample;
        }

        self.phase = self.phase + self.phase_step;

        const one_vec: FloatVec = @splat(1.0);
        const wrap_mask = self.phase >= one_vec;
        self.phase = @select(f32, wrap_mask, self.phase - one_vec, self.phase);

        inline for (0..VECTOR_SIZE) |i| {
            out_buffer[i] = samples_arr[i];
        }
    }
};
