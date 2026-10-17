const std = @import("std");

pub const SubOsc = struct {
    phase: f32,
    freq_ratio: f32,
    level: f32,
    waveform: u8, // 0 = Sine, 1 = Triangle, 2 = Square

    pub fn init() SubOsc {
        return .{
            .phase = 0.0,
            .freq_ratio = 0.5,
            .level = 0.8,
            .waveform = 0,
        };
    }

    pub fn reset(self: *SubOsc) void {
        self.phase = 0.0;
    }

    pub fn process(self: *SubOsc, main_phase_step: f32) f32 {
        self.phase += main_phase_step * self.freq_ratio;
        if (self.phase >= 1.0) {
            self.phase -= 1.0;
        }

        const raw: f32 = switch (self.waveform) {
            0 => @sin(self.phase * std.math.tau),
            1 => 2.0 * @abs(2.0 * (self.phase - @floor(self.phase + 0.5))) - 1.0,
            2 => if (self.phase < 0.5) @as(f32, 1.0) else @as(f32, -1.0),
            else => 0.0,
        };

        return raw * self.level;
    }
};
