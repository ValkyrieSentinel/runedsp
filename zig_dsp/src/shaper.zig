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

pub const AsymmetricShaper = struct {
    drive: f32,
    asymmetry: f32,
    mix: f32,

    pub fn init() AsymmetricShaper {
        return .{
            .drive = 2.0,
            .asymmetry = 0.15,
            .mix = 1.0,
        };
    }

    pub fn setDrive(self: *AsymmetricShaper, drive: f32) void {
        self.drive = std.math.clamp(drive, 1.0, 20.0);
    }

    pub fn setAsymmetry(self: *AsymmetricShaper, asymmetry: f32) void {
        self.asymmetry = std.math.clamp(asymmetry, -0.5, 0.5);
    }

    pub fn setMix(self: *AsymmetricShaper, mix: f32) void {
        self.mix = std.math.clamp(mix, 0.0, 1.0);
    }

    pub fn process_vector(self: *AsymmetricShaper, input: FloatVec) FloatVec {
        const drive_vec: FloatVec = @splat(self.drive);
        const asym_vec: FloatVec = @splat(self.asymmetry);
        const mix_vec: FloatVec = @splat(self.mix);
        const one: FloatVec = @splat(1.0);
        const zero: FloatVec = @splat(0.0);

        const biased = input + asym_vec;
        const driven = biased * drive_vec;

        const mask = driven >= zero;
        const pos_path = vtanh(driven);
        const neg_path = driven / (one + @abs(driven));
        const saturated = @select(f32, mask, pos_path, neg_path);

        const sum = @reduce(.Add, saturated);
        const dc_offset = sum / @as(f32, VECTOR_SIZE);
        const dc_offset_vec: FloatVec = @splat(dc_offset);
        const dc_blocked = saturated - dc_offset_vec;

        const makeup: f32 = 1.0 / @sqrt(self.drive);
        const makeup_vec: FloatVec = @splat(makeup);
        const compensated = dc_blocked * makeup_vec;

        return input * (one - mix_vec) + compensated * mix_vec;
    }
};
