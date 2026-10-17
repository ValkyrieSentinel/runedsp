const std = @import("std");
const poly = @import("poly.zig");
const envelope = @import("envelope.zig");

const c = @cImport({
    @cInclude("stdio.h");
});

fn logStep(step: [*:0]const u8) void {
    const file = c.fopen("/tmp/runedsp_debug.log", "a");
    if (file != null) {
        _ = c.fprintf(file, "[RuneDSP] %s\n", step);
        _ = c.fclose(file);
    }
}

export fn runedsp_init(sample_rate: f32) ?*anyopaque {
    logStep("1. Початок runedsp_init");
    const allocator = std.heap.page_allocator;
    const synth = allocator.create(poly.PolyEngine) catch {
        logStep("ПОМИЛКА: allocator.create");
        return null;
    };
    logStep("2. allocator.create успішно");

    synth.initInto(sample_rate);
    logStep("3. PolyEngine.initInto успішно");
    logStep("4. runedsp_init завершено, повертаємо handle");
    return @ptrCast(synth);
}

export fn runedsp_free(handle: ?*anyopaque) void {
    logStep("5. Викликано runedsp_free");
    if (handle) |ptr| {
        const allocator = std.heap.page_allocator;
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        allocator.destroy(synth);
        logStep("6. allocator.destroy завершено");
    }
}

export fn runedsp_note_on(handle: ?*anyopaque, note: u8, velocity: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        synth.noteOn(note, velocity);
    }
}

export fn runedsp_note_off(handle: ?*anyopaque, note: u8) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        synth.noteOff(note);
    }
}

export fn runedsp_set_cutoff(handle: ?*anyopaque, cutoff: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setCutoff(cutoff);
}
export fn runedsp_set_resonance(handle: ?*anyopaque, res: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setResonance(res);
}
export fn runedsp_set_filter_drive(handle: ?*anyopaque, drive: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setFilterDrive(drive);
}
export fn runedsp_set_shaper_drive(handle: ?*anyopaque, drive: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setShaperDrive(drive);
}
export fn runedsp_set_shaper_asymmetry(handle: ?*anyopaque, asym: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setShaperAsymmetry(asym);
}
export fn runedsp_set_morph(handle: ?*anyopaque, morph: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setMorph(morph);
}
export fn runedsp_set_lfo_rate(handle: ?*anyopaque, rate: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setLfoRate(rate);
}
export fn runedsp_set_env_amount(handle: ?*anyopaque, amount: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setEnvAmount(amount);
}

export fn runedsp_set_master_saturation(handle: ?*anyopaque, drive: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setMasterSaturation(drive);
}
export fn runedsp_set_master_makeup_gain(handle: ?*anyopaque, gain: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setMasterMakeupGain(gain);
}

export fn runedsp_set_env_attack_time(handle: ?*anyopaque, time: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.env.setAttack(time);
    }
}
export fn runedsp_set_env_hold_time(handle: ?*anyopaque, time: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.env.setHold(time);
    }
}
export fn runedsp_set_env_decay_time(handle: ?*anyopaque, time: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.env.setDecay(time);
    }
}
export fn runedsp_set_env_sustain_level(handle: ?*anyopaque, level: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.env.setSustain(level);
    }
}
export fn runedsp_set_env_release_time(handle: ?*anyopaque, time: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.env.setRelease(time);
    }
}
export fn runedsp_set_env_attack_shape(handle: ?*anyopaque, shape: u8) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        const curve_shape: envelope.CurveShape = switch (shape) {
            0 => .linear,
            1 => .exponential,
            2 => .logarithmic,
            3 => .scurve,
            else => .exponential,
        };
        for (&synth.voices) |*slot| slot.voice.env.setAttackShape(curve_shape);
    }
}
export fn runedsp_set_env_velocity_to_attack(handle: ?*anyopaque, amount: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.env.setVelocityToAttack(amount);
    }
}
export fn runedsp_set_env_loop(handle: ?*anyopaque, enabled: bool) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        const mode: envelope.LoopMode = if (enabled) .attack_decay else .off;
        for (&synth.voices) |*slot| slot.voice.env.setLoopMode(mode);
    }
}

export fn runedsp_set_chorus_rate(handle: ?*anyopaque, rate: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.setChorusRate(rate);
    }
}
export fn runedsp_set_chorus_depth(handle: ?*anyopaque, depth: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.setChorusDepth(depth);
    }
}
export fn runedsp_set_chorus_feedback(handle: ?*anyopaque, feedback: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.setChorusFeedback(feedback);
    }
}
export fn runedsp_set_chorus_mix(handle: ?*anyopaque, mix: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.setChorusMix(mix);
    }
}
export fn runedsp_set_chorus_filter_cutoff(handle: ?*anyopaque, cutoff: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.setChorusFilterCutoff(cutoff);
    }
}
export fn runedsp_set_chorus_enabled(handle: ?*anyopaque, enabled: bool) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.setChorusEnabled(enabled);
    }
}

export fn runedsp_set_sub_level(handle: ?*anyopaque, level: f32) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.sub_osc.level = level;
    }
}

export fn runedsp_set_sub_octave(handle: ?*anyopaque, octave: u8) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        const ratio: f32 = switch (octave) {
            1 => 0.5,
            2 => 0.25,
            else => 1.0,
        };
        for (&synth.voices) |*slot| slot.voice.sub_osc.freq_ratio = ratio;
    }
}

export fn runedsp_set_sub_waveform(handle: ?*anyopaque, wf: u8) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));
        for (&synth.voices) |*slot| slot.voice.sub_osc.waveform = wf;
    }
}

export fn runedsp_set_reverb_mix(handle: ?*anyopaque, mix: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setReverbMix(mix);
}
export fn runedsp_set_reverb_feedback(handle: ?*anyopaque, fb: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setReverbFeedback(fb);
}
export fn runedsp_set_reverb_damp(handle: ?*anyopaque, damp: f32) void {
    if (handle) |ptr| @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr))).setReverbDamp(damp);
}

export fn runedsp_process(handle: ?*anyopaque, output_ptr: [*c]f32, num_floats: usize) void {
    if (handle) |ptr| {
        const synth = @as(*poly.PolyEngine, @ptrCast(@alignCast(ptr)));

        var block_buf: [poly.VECTOR_SIZE * 2]f32 = undefined;
        var i: usize = 0;

        while (i < num_floats) {
            const remaining_floats = num_floats - i;
            const frames_to_process = @min(poly.VECTOR_SIZE, remaining_floats / 2);

            if (frames_to_process == 0) break;

            @memset(&block_buf, 0.0);

            synth.processBlock(block_buf[0 .. poly.VECTOR_SIZE * 2]);

            const floats_to_copy = frames_to_process * 2;
            for (0..floats_to_copy) |j| {
                output_ptr[i + j] = block_buf[j];
            }

            i += floats_to_copy;
        }
    }
}
