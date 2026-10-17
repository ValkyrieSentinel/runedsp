const std = @import("std");

pub const EnvelopeState = enum {
    idle,
    attack,
    hold,
    decay,
    sustain,
    release,
};

pub const CurveShape = enum {
    linear,
    exponential,
    logarithmic,
    scurve,

    pub fn apply(self: CurveShape, progress: f32) f32 {
        return switch (self) {
            .linear => progress,
            .exponential => {
                if (progress <= 0.0) return 0.0;
                return std.math.pow(f32, progress, 0.3);
            },
            .logarithmic => {
                if (progress >= 1.0) return 1.0;
                return 1.0 - std.math.pow(f32, 1.0 - progress, 0.3);
            },
            .scurve => {
                const x = std.math.clamp(progress, 0.0, 1.0);
                return x * x * (3.0 - 2.0 * x);
            },
        };
    }
};

pub const LoopMode = enum {
    off,
    attack_decay,
    full,
};

pub const RetriggerMode = enum {
    restart,
    retrigger,
    legato,
};

pub const AdsrEnvelope = struct {
    sample_rate: f32,
    state: EnvelopeState,

    current_level: f32,
    velocity: f32,

    attack_time: f32,
    hold_time: f32,
    decay_time: f32,
    sustain_level: f32,
    release_time: f32,

    attack_shape: CurveShape,
    hold_shape: CurveShape,
    decay_shape: CurveShape,
    release_shape: CurveShape,

    velocity_to_attack: f32,
    velocity_to_decay: f32,
    velocity_to_sustain: f32,
    velocity_to_release: f32,

    loop_mode: LoopMode,
    retrigger_mode: RetriggerMode,

    stage_progress: f32,
    hold_counter: f32,

    pub fn init(sample_rate: f32) AdsrEnvelope {
        return AdsrEnvelope{
            .sample_rate = sample_rate,
            .state = .idle,
            .current_level = 0.0,
            .velocity = 1.0,

            .attack_time = 0.01,
            .hold_time = 0.0,
            .decay_time = 0.3,
            .sustain_level = 0.6,
            .release_time = 0.2,

            .attack_shape = .exponential,
            .hold_shape = .linear,
            .decay_shape = .logarithmic,
            .release_shape = .exponential,

            .velocity_to_attack = -0.5,
            .velocity_to_decay = 0.0,
            .velocity_to_sustain = 0.0,
            .velocity_to_release = 0.0,

            .loop_mode = .off,
            .retrigger_mode = .restart,

            .stage_progress = 0.0,
            .hold_counter = 0.0,
        };
    }

    pub fn setAttack(self: *AdsrEnvelope, time: f32) void {
        self.attack_time = @max(time, 0.001);
    }

    pub fn setHold(self: *AdsrEnvelope, time: f32) void {
        self.hold_time = @max(time, 0.0);
    }

    pub fn setDecay(self: *AdsrEnvelope, time: f32) void {
        self.decay_time = @max(time, 0.001);
    }

    pub fn setSustain(self: *AdsrEnvelope, level: f32) void {
        self.sustain_level = std.math.clamp(level, 0.0, 1.0);
    }

    pub fn setRelease(self: *AdsrEnvelope, time: f32) void {
        self.release_time = @max(time, 0.001);
    }

    pub fn setAttackShape(self: *AdsrEnvelope, shape: CurveShape) void {
        self.attack_shape = shape;
    }

    pub fn setHoldShape(self: *AdsrEnvelope, shape: CurveShape) void {
        self.hold_shape = shape;
    }

    pub fn setDecayShape(self: *AdsrEnvelope, shape: CurveShape) void {
        self.decay_shape = shape;
    }

    pub fn setReleaseShape(self: *AdsrEnvelope, shape: CurveShape) void {
        self.release_shape = shape;
    }

    pub fn setVelocityToAttack(self: *AdsrEnvelope, amount: f32) void {
        self.velocity_to_attack = std.math.clamp(amount, -1.0, 1.0);
    }

    pub fn setVelocityToDecay(self: *AdsrEnvelope, amount: f32) void {
        self.velocity_to_decay = std.math.clamp(amount, -1.0, 1.0);
    }

    pub fn setVelocityToSustain(self: *AdsrEnvelope, amount: f32) void {
        self.velocity_to_sustain = std.math.clamp(amount, 0.0, 1.0);
    }

    pub fn setVelocityToRelease(self: *AdsrEnvelope, amount: f32) void {
        self.velocity_to_release = std.math.clamp(amount, -1.0, 1.0);
    }

    pub fn setLoopMode(self: *AdsrEnvelope, mode: LoopMode) void {
        self.loop_mode = mode;
    }

    pub fn setRetriggerMode(self: *AdsrEnvelope, mode: RetriggerMode) void {
        self.retrigger_mode = mode;
    }

    pub fn triggerOn(self: *AdsrEnvelope, velocity: f32) void {
        self.velocity = std.math.clamp(velocity, 0.0, 1.0);

        if (self.retrigger_mode == .restart) {
            self.stage_progress = 0.0;
            self.current_level = 0.0;
        }

        self.state = .attack;
    }

    pub fn triggerOff(self: *AdsrEnvelope) void {
        if (self.loop_mode != .off) {
            self.loop_mode = .off;
        }

        self.state = .release;
        self.stage_progress = 0.0;
    }

    pub fn process(self: *AdsrEnvelope) f32 {
        const vel_to_attack_mod = 1.0 + (self.velocity_to_attack * (1.0 - self.velocity));
        const vel_to_decay_mod = 1.0 + (self.velocity_to_decay * (1.0 - self.velocity));
        const vel_to_sustain_mod = 1.0 + (self.velocity_to_sustain * (1.0 - self.velocity));
        const vel_to_release_mod = 1.0 + (self.velocity_to_release * (1.0 - self.velocity));

        const attack_time_mod = self.attack_time * vel_to_attack_mod;
        const decay_time_mod = self.decay_time * vel_to_decay_mod;
        const sustain_level_mod = self.sustain_level * vel_to_sustain_mod;
        const release_time_mod = self.release_time * vel_to_release_mod;

        switch (self.state) {
            .idle => {
                self.current_level = 0.0;
                self.stage_progress = 0.0;
            },

            .attack => {
                const samples_in_stage = attack_time_mod * self.sample_rate;
                self.stage_progress += 1.0 / samples_in_stage;

                const curved_progress = self.attack_shape.apply(self.stage_progress);

                const start_level = if (self.retrigger_mode == .retrigger and self.stage_progress < 0.01)
                    self.current_level
                else
                    0.0;

                self.current_level = start_level + (1.0 - start_level) * curved_progress;

                if (self.stage_progress >= 1.0) {
                    self.current_level = 1.0;
                    self.stage_progress = 0.0;

                    if (self.hold_time > 0.0) {
                        self.state = .hold;
                    } else {
                        self.state = .decay;
                    }
                }
            },

            .hold => {
                const samples_in_stage = self.hold_time * self.sample_rate;
                self.hold_counter += 1.0;

                self.current_level = 1.0;

                if (self.hold_counter >= samples_in_stage) {
                    self.hold_counter = 0.0;
                    self.stage_progress = 0.0;
                    self.state = .decay;
                }
            },

            .decay => {
                const samples_in_stage = decay_time_mod * self.sample_rate;
                self.stage_progress += 1.0 / samples_in_stage;

                const curved_progress = self.decay_shape.apply(self.stage_progress);

                self.current_level = 1.0 - (1.0 - sustain_level_mod) * curved_progress;

                if (self.stage_progress >= 1.0) {
                    self.current_level = sustain_level_mod;
                    self.stage_progress = 0.0;
                    self.state = .sustain;
                }
            },

            .sustain => {
                self.current_level = sustain_level_mod;

                if (self.loop_mode == .attack_decay) {
                    self.state = .attack;
                    self.stage_progress = 0.0;
                } else if (self.loop_mode == .full and self.hold_time > 0.0) {
                    self.state = .hold;
                    self.hold_counter = 0.0;
                }
            },

            .release => {
                const samples_in_stage = release_time_mod * self.sample_rate;
                self.stage_progress += 1.0 / samples_in_stage;

                const curved_progress = self.release_shape.apply(self.stage_progress);

                const release_start_level = if (self.stage_progress < 0.01)
                    self.current_level
                else
                    sustain_level_mod;

                self.current_level = release_start_level * (1.0 - curved_progress);

                if (self.stage_progress >= 1.0 or self.current_level < 0.0001) {
                    self.current_level = 0.0;
                    self.stage_progress = 0.0;
                    self.state = .idle;
                }
            },
        }

        return self.current_level;
    }

    pub fn isIdle(self: *AdsrEnvelope) bool {
        return self.state == .idle;
    }

    pub fn getState(self: *AdsrEnvelope) EnvelopeState {
        return self.state;
    }

    pub fn getCurrentLevel(self: *AdsrEnvelope) f32 {
        return self.current_level;
    }
};
