const std = @import("std");

pub const VECTOR_SIZE = 8;
pub const FloatVec = @Vector(VECTOR_SIZE, f32);

pub fn vtanh(x: FloatVec) FloatVec {
    const two_log2e: FloatVec = @splat(2.8853900817779268); // 2 * log2(e)
    const one: FloatVec = @splat(1.0);
    const two: FloatVec = @splat(2.0);
    const e = @exp2(x * two_log2e);
    return one - two / (e + one);
}

pub const FilterMode = enum {
    lowpass,
    bandpass,
    highpass,
};

pub const SvfFilter = struct {
    sample_rate: f32,
    cutoff: f32,
    resonance: f32,
    drive: f32,
    mode: FilterMode,

    ic1eq: FloatVec,
    ic2eq: FloatVec,

    pub fn init(sample_rate: f32) SvfFilter {
        return .{
            .sample_rate = sample_rate,
            .cutoff = 1200.0,
            .resonance = 1.0,
            .drive = 1.0,
            .mode = .lowpass,
            .ic1eq = @splat(0.0),
            .ic2eq = @splat(0.0),
        };
    }

    pub fn setMode(self: *SvfFilter, mode: FilterMode) void {
        self.mode = mode;
    }

    pub fn setCutoff(self: *SvfFilter, cutoff: f32) void {
        self.cutoff = std.math.clamp(cutoff, 20.0, self.sample_rate * 0.49);
    }

    pub fn setResonance(self: *SvfFilter, res: f32) void {
        self.resonance = std.math.clamp(res, 0.1, 15.0);
    }

    pub fn setDrive(self: *SvfFilter, drive: f32) void {
        self.drive = std.math.clamp(drive, 1.0, 16.0);
    }
    pub fn process_vector(self: *SvfFilter, input: FloatVec) FloatVec {
        const one: FloatVec = @splat(1.0);
        const two: FloatVec = @splat(2.0);
        const drive_vec: FloatVec = @splat(self.drive);

        const g_val = @tan(std.math.pi * self.cutoff / self.sample_rate);
        const g: FloatVec = @splat(g_val);

        const resonance_normalized = std.math.clamp(self.resonance / 15.0, 0.0, 1.0);
        const k: FloatVec = @splat(2.0 * (1.0 - resonance_normalized));

        const a1 = one / (one + g * (g + k));
        const a2 = g * a1;
        const a3 = g * a2;

        const v3 = input - self.ic2eq;
        const v1 = a1 * self.ic1eq + a2 * v3; // bandpass
        const saturated_v1 = vtanh(v1 * drive_vec);
        const v2 = self.ic2eq + a2 * self.ic1eq + a3 * saturated_v1; // lowpass

        self.ic1eq = two * v1 - self.ic1eq;
        self.ic2eq = two * v2 - self.ic2eq;

        // Denormal protection
        const thresh: FloatVec = @splat(1e-15);
        const zero: FloatVec = @splat(0.0);
        self.ic1eq = @select(f32, @abs(self.ic1eq) < thresh, zero, self.ic1eq);
        self.ic2eq = @select(f32, @abs(self.ic2eq) < thresh, zero, self.ic2eq);

        return switch (self.mode) {
            .lowpass => v2,
            .bandpass => saturated_v1,
            .highpass => v3 - k * saturated_v1 - v2,
        };
    }
};
