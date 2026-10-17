use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is not set"));
    
    let zig_src = "zig_dsp/src/lib.zig";
    let output_lib = out_dir.join("libzig_dsp.a"); 

    let output = Command::new("zig")
        .arg("build-lib")
        .arg(zig_src)
        .arg("-O")
        .arg("ReleaseFast")
        .arg("-lc")  // ✅ Потрібно для std.heap.c_allocator
        .arg(format!("-femit-bin={}", output_lib.display()))
        .output()
        .expect("Failed to execute 'zig'. Make sure 'zig' is in PATH.");

    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        
        panic!(
            "\n=== ZIG COMPILATION FAILED ===\nSTDOUT:\n{}\nSTDERR:\n{}\n==============================\n",
            stdout, stderr
        );
    }

    println!("cargo:rustc-link-search=native={}", out_dir.display());
    println!("cargo:rustc-link-lib=static=zig_dsp");
    
   
    println!("cargo:rerun-if-changed=zig_dsp/src/lib.zig");
    println!("cargo:rerun-if-changed=zig_dsp/src/poly.zig");
    println!("cargo:rerun-if-changed=zig_dsp/src/engine.zig");
    println!("cargo:rerun-if-changed=zig_dsp/src/filter.zig");
    println!("cargo:rerun-if-changed=zig_dsp/src/shaper.zig");
    println!("cargo:rerun-if-changed=zig_dsp/src/envelope.zig");
    println!("cargo:rerun-if-changed=zig_dsp/src/lfo.zig");
    println!("cargo:rerun-if-changed=zig_dsp/src/wavetable.zig");
}