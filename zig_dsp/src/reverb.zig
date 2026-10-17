const std = @import("std");

const MAX_DELAY = 16384;

pub const StereoReverb = struct {
    delay_l: [MAX_DELAY]f32 = undefined,
    delay_r: [MAX_DELAY]f32 = undefined,
    idx_l: usize = 0,
    idx_r: usize = 0,

    mix: f32,
    feedback: f32, // 0.0 - 0.85
    damp: f32, // 0.0 - 1.0

    lp_state_l: f32 = 0.0,
    lp_state_r: f32 = 0.0,

    pub fn init() StereoReverb {
        var rev = StereoReverb{
            .mix = 0.3,
            .feedback = 0.6,
            .damp = 0.5,
            .delay_l = undefined,
            .delay_r = undefined,
            .idx_l = 0,
            .idx_r = 0,
            .lp_state_l = 0.0,
            .lp_state_r = 0.0,
        };

        @memset(&rev.delay_l, 0.0);
        @memset(&rev.delay_r, 0.0);
        return rev;
    }

    pub fn process(self: *StereoReverb, in_l: f32, in_r: f32) struct { f32, f32 } {
        const out_l = self.delay_l[self.idx_l];
        const out_r = self.delay_r[self.idx_r];

        self.lp_state_l = out_l * self.damp + self.lp_state_l * (1.0 - self.damp);
        self.lp_state_r = out_r * self.damp + self.lp_state_r * (1.0 - self.damp);

        self.delay_l[self.idx_l] = in_l + self.lp_state_l * self.feedback;
        self.delay_r[self.idx_r] = in_r + self.lp_state_r * self.feedback;

        self.idx_l = (self.idx_l + 1) % MAX_DELAY;
        self.idx_r = (self.idx_r + 1) % MAX_DELAY;

        const final_l = in_l * (1.0 - self.mix) + out_l * self.mix;
        const final_r = in_r * (1.0 - self.mix) + out_r * self.mix;

        return .{ final_l, final_r };
    }
};
