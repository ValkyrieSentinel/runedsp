const std = @import("std");

pub const LfoShape = enum {
    sine,
    triangle,
    square,
    saw,
};

pub const Lfo = struct {
    sample_rate: f32,
    frequency: f32,
    phase: f32,
    phase_increment: f32,
    shape: LfoShape,

    sine_y1: f32,
    sine_y2: f32,
    sine_b: f32,

    pub fn init(sample_rate: f32) Lfo {
        var lfo = Lfo{
            .sample_rate = sample_rate,
            .frequency = 1.0,
            .phase = 0.0,
            .phase_increment = 0.0,
            .shape = .sine,
            .sine_y1 = 0.0,
            .sine_y2 = 0.0,
            .sine_b = 0.0,
        };
        lfo.updateIncrement();
        return lfo;
    }

    pub fn setFrequency(self: *Lfo, freq: f32) void {
        self.frequency = std.math.clamp(freq, 0.01, 40.0);
        self.updateIncrement();
    }

    pub fn setShape(self: *Lfo, shape: LfoShape) void {
        self.shape = shape;
    }

    pub fn reset(self: *Lfo) void {
        self.phase = 0.0;
        self.sine_y1 = 0.0;
        self.sine_y2 = 0.0;
    }

    fn updateIncrement(self: *Lfo) void {
        self.phase_increment = self.frequency / self.sample_rate;

        // b = 2 * cos(2π * f / fs)
        self.sine_b = 2.0 * @cos(2.0 * std.math.pi * self.frequency / self.sample_rate);

        self.sine_y1 = @sin(-2.0 * std.math.pi * self.frequency / self.sample_rate);
        self.sine_y2 = @sin(-4.0 * std.math.pi * self.frequency / self.sample_rate);
    }

    pub fn process(self: *Lfo) f32 {
        const val = switch (self.shape) {
            //  Magic Circle: y[n] = b * y[n-1] - y[n-2]

            .sine => blk: {
                const y0 = self.sine_b * self.sine_y1 - self.sine_y2;
                self.sine_y2 = self.sine_y1;
                self.sine_y1 = y0;
                break :blk y0;
            },

            .triangle => 4.0 * @abs(self.phase - 0.5) - 1.0,

            .square => blk: {
                const raw: f32 = if (self.phase < 0.5) 1.0 else -1.0;

                const transition_width = 0.05;
                const dist_to_edge = @abs(self.phase - 0.5);

                if (dist_to_edge < transition_width) {
                    const t = dist_to_edge / transition_width;
                    const smoothed = std.math.tanh((t - 0.5) * 8.0);
                    break :blk smoothed;
                }
                break :blk raw;
            },

            .saw => blk: {
                const raw = 2.0 * self.phase - 1.0;

                const transition_width = 0.05;

                if (self.phase > (1.0 - transition_width)) {
                    const t = (1.0 - self.phase) / transition_width;
                    const smoothed = std.math.tanh((t - 0.5) * 8.0);
                    break :blk smoothed;
                }
                break :blk raw;
            },
        };

        self.phase += self.phase_increment;
        if (self.phase >= 1.0) {
            self.phase -= 1.0;
        }

        return val;
    }

    pub fn processVector(self: *Lfo) FloatVec {
        var result: [VECTOR_SIZE]f32 = undefined;
        inline for (0..VECTOR_SIZE) |i| {
            result[i] = self.process();
        }
        return result;
    }
};

const VECTOR_SIZE = 8;
const FloatVec = @Vector(VECTOR_SIZE, f32);
