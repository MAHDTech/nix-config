pub mod config;
pub mod engine;
pub mod system;
pub mod downloader;
pub mod quant;

pub use config::ModelSpec;
pub use system::HardwareInfo;
pub use downloader::Downloader;
pub use quant::Quantizer;

pub fn launch<B: burn::tensor::backend::Backend>(
    spec: &ModelSpec,
    _device: &burn::tensor::Device<B>,
) -> Result<(), String> {
    log::info!("Launching model: {}", spec.name);
    let _hw = HardwareInfo::detect();
    if !spec.is_supported(&_hw) {
        return Err("Hardware not supported".to_string());
    }

    let _weights = Downloader::download_model(spec)?;
    log::info!("Model launched successfully!");
    Ok(())
}
