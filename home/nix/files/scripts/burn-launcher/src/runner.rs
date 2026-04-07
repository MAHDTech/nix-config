use crate::config::ModelSpec;
use burn::backend::{NdArray, Wgpu};

pub fn run_engine(spec: ModelSpec, force_cpu: bool) -> Result<(), Box<dyn std::error::Error>> {
    println!("⚙️  Initializing Burn Backend...");

    if force_cpu {
        println!("🚀 Backend: burn-ndarray (CPU)");
        crate::models::execute::<NdArray>(&spec)?;
    } else {
        println!("🚀 Backend: burn-wgpu (GPU via Vulkan/Metal)");
        crate::models::execute::<Wgpu>(&spec)?;
    }

    Ok(())
}
