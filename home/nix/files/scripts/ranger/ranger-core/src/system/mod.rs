pub mod ram;
pub mod vram;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct HardwareInfo {
    pub total_ram_gb: f64,
    pub used_ram_gb: f64,
    pub gpu_vendor: String,
    pub total_vram_gb: f64,
}

impl HardwareInfo {
    pub fn detect() -> Self {
        let (total_ram_gb, used_ram_gb) = ram::get_system_ram_gb();
        let (gpu_vendor, total_vram_gb) = vram::get_gpu_vendor_and_vram();

        Self {
            total_ram_gb,
            used_ram_gb,
            gpu_vendor,
            total_vram_gb,
        }
    }
}
