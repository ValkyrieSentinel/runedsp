use nih_plug::prelude::*;
use std::ffi::c_void;
use std::ptr;
use std::sync::Arc;
use std::io::Write;

#[derive(Enum, Debug, Clone, Copy, PartialEq)]
pub enum CurveShape {
    #[name = "Linear"]
    Linear,
    #[name = "Exponential"]
    Exponential,
    #[name = "Logarithmic"]
    Logarithmic,
    #[name = "S-Curve"]
    SCurve,
}
unsafe extern "C" {
    fn runedsp_init(sample_rate: f32) -> *mut c_void;
    fn runedsp_free(handle: *mut c_void);
    
    fn runedsp_note_on(handle: *mut c_void, note: u8, velocity: f32);
    fn runedsp_note_off(handle: *mut c_void, note: u8);
    
    fn runedsp_process(handle: *mut c_void, output_ptr: *mut f32, num_floats: usize);
    
    fn runedsp_set_cutoff(handle: *mut c_void, cutoff: f32);
    fn runedsp_set_resonance(handle: *mut c_void, res: f32);
    fn runedsp_set_filter_drive(handle: *mut c_void, drive: f32);
    fn runedsp_set_shaper_drive(handle: *mut c_void, drive: f32);
    fn runedsp_set_shaper_asymmetry(handle: *mut c_void, asym: f32);
    fn runedsp_set_morph(handle: *mut c_void, morph: f32);
    fn runedsp_set_lfo_rate(handle: *mut c_void, rate: f32);
    fn runedsp_set_master_saturation(handle: *mut c_void, drive: f32);
    fn runedsp_set_master_makeup_gain(handle: *mut c_void, gain: f32);
    
    fn runedsp_set_env_attack_time(handle: *mut c_void, time: f32);
    fn runedsp_set_env_hold_time(handle: *mut c_void, time: f32);
    fn runedsp_set_env_decay_time(handle: *mut c_void, time: f32);
    fn runedsp_set_env_sustain_level(handle: *mut c_void, level: f32);
    fn runedsp_set_env_release_time(handle: *mut c_void, time: f32);
    fn runedsp_set_env_attack_shape(handle: *mut c_void, shape: u8);
    fn runedsp_set_env_velocity_to_attack(handle: *mut c_void, amount: f32);
    fn runedsp_set_env_loop(handle: *mut c_void, enabled: bool);
    fn runedsp_set_env_amount(handle: *mut c_void, amount: f32);
    
    fn runedsp_set_chorus_rate(handle: *mut c_void, rate: f32);
    fn runedsp_set_chorus_depth(handle: *mut c_void, depth: f32);
    fn runedsp_set_chorus_feedback(handle: *mut c_void, feedback: f32);
    fn runedsp_set_chorus_mix(handle: *mut c_void, mix: f32);
    fn runedsp_set_chorus_filter_cutoff(handle: *mut c_void, cutoff: f32);
    fn runedsp_set_chorus_enabled(handle: *mut c_void, enabled: bool);
    
    fn runedsp_set_sub_level(handle: *mut c_void, level: f32);
    fn runedsp_set_sub_octave(handle: *mut c_void, octave: u8);
    fn runedsp_set_sub_waveform(handle: *mut c_void, wf: u8);
 
    fn runedsp_set_reverb_mix(handle: *mut c_void, mix: f32);
    fn runedsp_set_reverb_feedback(handle: *mut c_void, fb: f32);
    fn runedsp_set_reverb_damp(handle: *mut c_void, damp: f32);
}

fn log_rust(msg: &str) {
    if let Ok(mut file) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open("/tmp/runedsp_rust.log")
    {
        let _ = writeln!(file, "[Rust] {}", msg);
    }
}

struct RuneDsp {
    params: Arc<RuneParams>,
    synth_handle: *mut c_void,
    sample_rate: f32,
}

unsafe impl Send for RuneDsp {}
unsafe impl Sync for RuneDsp {}

impl Drop for RuneDsp {
    fn drop(&mut self) {
        log_rust("Drop викликано");
        if !self.synth_handle.is_null() {
            unsafe {
                runedsp_free(self.synth_handle);
            }
        }
    }
}

#[derive(Params)]
struct RuneParams {
    #[id = "gain"] pub gain: FloatParam,
    #[id = "cutoff"] pub cutoff: FloatParam,
    #[id = "resonance"] pub resonance: FloatParam,
    #[id = "filter_drive"] pub filter_drive: FloatParam,
    #[id = "shaper_drive"] pub shaper_drive: FloatParam,
    #[id = "shaper_asym"] pub shaper_asym: FloatParam,
    #[id = "morph"] pub morph: FloatParam,
    #[id = "lfo_rate"] pub lfo_rate: FloatParam,
    #[id = "master_saturation"] pub master_saturation: FloatParam,
    
    #[id = "env_attack"] pub env_attack: FloatParam,
    #[id = "env_hold"] pub env_hold: FloatParam,
    #[id = "env_decay"] pub env_decay: FloatParam,
    #[id = "env_sustain"] pub env_sustain: FloatParam,
    #[id = "env_release"] pub env_release: FloatParam,
    
    #[id = "env_attack_shape"] pub env_attack_shape: EnumParam<CurveShape>,
    #[id = "env_velocity_to_attack"] pub env_velocity_to_attack: FloatParam,
    #[id = "env_loop"] pub env_loop: BoolParam,
    #[id = "env_amount"] pub env_amount: FloatParam,
    
    #[id = "chorus_enabled"] pub chorus_enabled: BoolParam,
    #[id = "chorus_rate"] pub chorus_rate: FloatParam,
    #[id = "chorus_depth"] pub chorus_depth: FloatParam,
    #[id = "chorus_feedback"] pub chorus_feedback: FloatParam,
    #[id = "chorus_mix"] pub chorus_mix: FloatParam,
    #[id = "chorus_filter"] pub chorus_filter: FloatParam,
    
    #[id = "sub_level"] pub sub_level: FloatParam,
    #[id = "sub_octave"] pub sub_octave: IntParam,
    #[id = "sub_waveform"] pub sub_waveform: IntParam,

    #[id = "reverb_mix"] pub reverb_mix: FloatParam,
    #[id = "reverb_feedback"] pub reverb_feedback: FloatParam,
    #[id = "reverb_damp"] pub reverb_damp: FloatParam,
}

impl Default for RuneParams {
    fn default() -> Self {
        Self {
            gain: FloatParam::new("Master Gain", -6.0, FloatRange::Linear { min: -60.0, max: 0.0 }).with_unit(" dB"),
            cutoff: FloatParam::new("Filter Cutoff", 1500.0, FloatRange::Skewed { min: 20.0, max: 20000.0, factor: 0.25 }).with_unit(" Hz"),
            resonance: FloatParam::new("Filter Resonance", 1.0, FloatRange::Linear { min: 0.1, max: 14.9 }),
            filter_drive: FloatParam::new("Filter Drive", 1.0, FloatRange::Linear { min: 1.0, max: 10.0 }),
            shaper_drive: FloatParam::new("Shaper Drive", 2.0, FloatRange::Linear { min: 1.0, max: 20.0 }),
            shaper_asym: FloatParam::new("Shaper Asymmetry", 0.15, FloatRange::Linear { min: -0.5, max: 0.5 }),
            morph: FloatParam::new("Wavetable Morph", 0.0, FloatRange::Linear { min: 0.0, max: 15.0 }),
            lfo_rate: FloatParam::new("LFO Rate", 1.0, FloatRange::Skewed { min: 0.05, max: 20.0, factor: 0.4 }).with_unit(" Hz"),
            master_saturation: FloatParam::new("Master Dirt", 1.0, FloatRange::Linear { min: 1.0, max: 4.0 }),
            
            env_attack: FloatParam::new("Env Attack", 0.01, FloatRange::Skewed { min: 0.001, max: 5.0, factor: 0.3 }).with_unit(" s"),
            env_hold: FloatParam::new("Env Hold", 0.0, FloatRange::Skewed { min: 0.0, max: 2.0, factor: 0.3 }).with_unit(" s"),
            env_decay: FloatParam::new("Env Decay", 0.3, FloatRange::Skewed { min: 0.001, max: 5.0, factor: 0.3 }).with_unit(" s"),
            env_sustain: FloatParam::new("Env Sustain", 0.0, FloatRange::Linear { min: 0.0, max: 1.0 }),
            env_release: FloatParam::new("Env Release", 3.0, FloatRange::Skewed { min: 0.001, max: 5.0, factor: 0.3 }).with_unit(" s"),
            env_amount: FloatParam::new("Env Amount", 0.0, FloatRange::Linear { min: 0.0, max: 10000.0 }),
            
            env_attack_shape: EnumParam::new("Env Attack Shape", CurveShape::Exponential),
            env_velocity_to_attack: FloatParam::new("Vel → Attack", 0.0, FloatRange::Linear { min: -1.0, max: 1.0 }),
            env_loop: BoolParam::new("Env Loop", false),
            
            chorus_enabled: BoolParam::new("Chorus Enable", true),
            chorus_rate: FloatParam::new("Chorus Rate", 0.3, FloatRange::Skewed { min: 0.05, max: 3.0, factor: 0.4 }).with_unit(" Hz"),
            chorus_depth: FloatParam::new("Chorus Depth", 12.0, FloatRange::Linear { min: 5.0, max: 25.0 }).with_unit(" ms"),
            chorus_feedback: FloatParam::new("Chorus Feedback", 0.35, FloatRange::Linear { min: 0.0, max: 0.6 }),
            chorus_mix: FloatParam::new("Chorus Mix", 0.5, FloatRange::Linear { min: 0.0, max: 1.0 }),
            chorus_filter: FloatParam::new("Chorus Filter", 3000.0, FloatRange::Skewed { min: 500.0, max: 8000.0, factor: 0.3 }).with_unit(" Hz"),
            
            sub_level: FloatParam::new("Sub Level", 0.0, FloatRange::Linear { min: 0.0, max: 1.0 }),
            sub_octave: IntParam::new("Sub Octave", 1, IntRange::Linear { min: 1, max: 2 }),
            sub_waveform: IntParam::new("Sub Wave", 0, IntRange::Linear { min: 0, max: 2 }),

            reverb_mix: FloatParam::new("Reverb Mix", 0.5, FloatRange::Linear { min: 0.0, max: 1.0 }),
            reverb_feedback: FloatParam::new("Reverb Tail", 0.7, FloatRange::Linear { min: 0.1, max: 0.85 }),
            reverb_damp: FloatParam::new("Reverb Dark", 0.6, FloatRange::Linear { min: 0.1, max: 0.9 }),
        }
    }
}

impl Default for RuneDsp {
    fn default() -> Self {
        Self {
            params: Arc::new(RuneParams::default()),
            synth_handle: ptr::null_mut(),
            sample_rate: 44100.0,
        }
    }
}

impl Plugin for RuneDsp {
    const NAME: &'static str = "RuneDSP";
    const VENDOR: &'static str = "ValkyrieSentinel";
    const URL: &'static str = "https://github.com/ValkyrieSentinel/runedsp";
    const EMAIL: &'static str = "valkyriesentinel@gmail.com";
    const VERSION: &'static str = "0.1.0";

    const AUDIO_IO_LAYOUTS: &'static [AudioIOLayout] = &[AudioIOLayout {
        main_input_channels: None,
        main_output_channels: NonZeroU32::new(2),
        aux_input_ports: &[],
        aux_output_ports: &[],
        names: PortNames::const_default(),
    }];

    const MIDI_INPUT: MidiConfig = MidiConfig::Basic;
    const SAMPLE_ACCURATE_AUTOMATION: bool = true;
    type SysExMessage = ();
    type BackgroundTask = ();

    fn params(&self) -> Arc<dyn Params> {
        self.params.clone()
    }

    fn initialize(
        &mut self,
        _audio_io_layout: &AudioIOLayout,
        buffer_config: &BufferConfig,
        _context: &mut impl InitContext<Self>,
    ) -> bool {
        log_rust(&format!("1. Початок initialize, sample_rate = {}", buffer_config.sample_rate));
        self.sample_rate = buffer_config.sample_rate;
        
        unsafe {
            self.synth_handle = runedsp_init(self.sample_rate);
        }
        
        log_rust(&format!("2. runedsp_init повернув: {:?}", self.synth_handle));
        !self.synth_handle.is_null()
    }

    fn process(
        &mut self,
        buffer: &mut Buffer,
        _aux: &mut AuxiliaryBuffers,
        context: &mut impl ProcessContext<Self>,
    ) -> ProcessStatus {
        let handle = self.synth_handle;
        if handle.is_null() {
            return ProcessStatus::KeepAlive;
        }

        let p = &self.params;

        
        unsafe {
            runedsp_set_cutoff(handle, p.cutoff.value());
            runedsp_set_resonance(handle, p.resonance.value());
            runedsp_set_filter_drive(handle, p.filter_drive.value());
            runedsp_set_shaper_drive(handle, p.shaper_drive.value());
            runedsp_set_shaper_asymmetry(handle, p.shaper_asym.value());
            runedsp_set_morph(handle, p.morph.value());
            runedsp_set_lfo_rate(handle, p.lfo_rate.value());
            runedsp_set_master_saturation(handle, p.master_saturation.value());
            runedsp_set_master_makeup_gain(handle, 0.85);
            
            runedsp_set_env_attack_time(handle, p.env_attack.value());
            runedsp_set_env_amount(handle, p.env_amount.value());
            runedsp_set_env_hold_time(handle, p.env_hold.value());
            runedsp_set_env_decay_time(handle, p.env_decay.value());
            runedsp_set_env_sustain_level(handle, p.env_sustain.value());
            runedsp_set_env_release_time(handle, p.env_release.value());
            
            let shape_u8 = match p.env_attack_shape.value() {
                CurveShape::Linear => 0,
                CurveShape::Exponential => 1,
                CurveShape::Logarithmic => 2,
                CurveShape::SCurve => 3,
            };
            runedsp_set_env_attack_shape(handle, shape_u8);
            runedsp_set_env_velocity_to_attack(handle, p.env_velocity_to_attack.value());
            runedsp_set_env_loop(handle, p.env_loop.value());
            
            runedsp_set_chorus_enabled(handle, p.chorus_enabled.value());
            runedsp_set_chorus_rate(handle, p.chorus_rate.value());
            runedsp_set_chorus_depth(handle, p.chorus_depth.value() / 1000.0);
            runedsp_set_chorus_feedback(handle, p.chorus_feedback.value());
            runedsp_set_chorus_mix(handle, p.chorus_mix.value());
            runedsp_set_chorus_filter_cutoff(handle, p.chorus_filter.value());
            
            runedsp_set_sub_level(handle, p.sub_level.value());
            runedsp_set_sub_octave(handle, p.sub_octave.value() as u8);
            runedsp_set_sub_waveform(handle, p.sub_waveform.value() as u8);

            runedsp_set_reverb_mix(handle, p.reverb_mix.value());
            runedsp_set_reverb_feedback(handle, p.reverb_feedback.value());
            runedsp_set_reverb_damp(handle, p.reverb_damp.value());
        }

        
        while let Some(event) = context.next_event() {
            match event {
                NoteEvent::NoteOn { note, velocity, .. } => {
                    if velocity > 0.0 {
                        unsafe { runedsp_note_on(handle, note, velocity); }
                    } else {
                        unsafe { runedsp_note_off(handle, note); }
                    }
                }
                NoteEvent::NoteOff { note, .. } => {
                    unsafe { runedsp_note_off(handle, note); }
                }
                _ => {}
            }
        }

        
        let num_frames = buffer.samples();
        let out_channels = buffer.as_slice();
        let gain = util::db_to_gain(p.gain.value());
        
       
        let mut interleaved_buf: [f32; 16] = [0.0; 16];
        let mut processed = 0;
        
        while processed < num_frames {
            let frames_to_process = std::cmp::min(8, num_frames - processed);
            let floats_to_process = frames_to_process * 2;
            
            unsafe {
                runedsp_process(handle, interleaved_buf.as_mut_ptr(), floats_to_process);
            }
            
            
            if out_channels.len() >= 2 {
                for i in 0..frames_to_process {
                    let out_idx = processed + i;
                    let l_sample = interleaved_buf[i * 2];
                    let r_sample = interleaved_buf[i * 2 + 1];
                    
                    out_channels[0][out_idx] = l_sample * gain;
                    out_channels[1][out_idx] = r_sample * gain;
                }
            } else if out_channels.len() == 1 {
                for i in 0..frames_to_process {
                    let out_idx = processed + i;
                    let l_sample = interleaved_buf[i * 2];
                    let r_sample = interleaved_buf[i * 2 + 1];
                    out_channels[0][out_idx] = (l_sample + r_sample) * 0.5 * gain;
                }
            }
            
            processed += frames_to_process;
        }

        ProcessStatus::KeepAlive
    }
}


impl ClapPlugin for RuneDsp {
    const CLAP_ID: &'static str = "com.valkyriesentinel.runedsp";
    const CLAP_DESCRIPTION: Option<&'static str> = Some("Next-Gen Kernel-Guarded Synth Engine");
    const CLAP_MANUAL_URL: Option<&'static str> = None;
    const CLAP_SUPPORT_URL: Option<&'static str> = None;
    const CLAP_FEATURES: &'static [ClapFeature] = &[
        ClapFeature::Synthesizer,
        ClapFeature::Stereo,
        ClapFeature::Instrument,
    ];
}

impl Vst3Plugin for RuneDsp {
    const VST3_CLASS_ID: [u8; 16] = *b"RuneDSPEngine010";
   
    const VST3_SUBCATEGORIES: &'static [Vst3SubCategory] = &[
        Vst3SubCategory::Instrument,
    ];
}

nih_export_clap!(RuneDsp);
nih_export_vst3!(RuneDsp);