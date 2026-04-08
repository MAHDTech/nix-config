pub mod ram;
pub mod vram;

use ram::get_system_ram_gb;
use vram::get_gpu_vendor_and_vram;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MemoryStatus {
    Safe,    // Full fit
    Tight,   // Fits but will require swapping/tight squeeze
    Unsafe,  // Exceeds limits!
}

pub struct MemoryEvaluation {
    pub status: MemoryStatus,
    pub footprint_gb: f64,
    pub budget_gb: f64,
    pub device: String,
}

#[derive(Clone, Debug)]
pub struct HardwareBudget {
    pub device: String,
    pub budget_gb: f64,
}

pub fn get_hardware_budget(force_cpu: bool) -> HardwareBudget {
    let (vendor, vram_gb) = if force_cpu {
        ("cpu".to_string(), 0.0)
    } else {
        get_gpu_vendor_and_vram()
    };

    if vendor == "cpu" || vram_gb == 0.0 {
        let (total_ram, _) = get_system_ram_gb();
        HardwareBudget { device: "SYS".to_string(), budget_gb: total_ram }
    } else {
        HardwareBudget { device: vendor.to_uppercase(), budget_gb: vram_gb }
    }
}

pub fn evaluate_memory_with_context(
    required_ram_gb: Option<f64>,
    required_vram_gb: Option<f64>,
    context_len: usize,
    hw: &HardwareBudget,
) -> MemoryEvaluation {
    let base = if hw.device == "SYS" {
        required_ram_gb.unwrap_or(0.0)
    } else {
        required_vram_gb.unwrap_or_else(|| required_ram_gb.unwrap_or(0.0))
    };

    // Heuristic: every 4096 tokens typically consumes ~0.5 GB of KeyValue cache layer context
    let overhead = (context_len as f64 / 4096.0) * 0.5;
    let footprint = base + overhead;

    let status = if footprint <= hw.budget_gb * 0.75 {
        MemoryStatus::Safe
    } else if footprint <= hw.budget_gb * 0.90 {
        MemoryStatus::Tight
    } else {
        MemoryStatus::Unsafe
    };

    MemoryEvaluation {
        status,
        footprint_gb: footprint,
        budget_gb: hw.budget_gb,
        device: hw.device.clone(),
    }
}
