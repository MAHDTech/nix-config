
use std::process::Command;
use std::fs;

pub fn get_system_ram_gb() -> (f64, f64) {
    let mut sys = sysinfo::System::new();
    sys.refresh_memory();
    let total_ram_gb = sys.total_memory() as f64 / 1_073_741_824.0;
    let used_ram_gb = sys.used_memory() as f64 / 1_073_741_824.0;
    (total_ram_gb, used_ram_gb)
}

pub fn get_gpu_vendor_and_vram() -> (String, f64) {
    // 1. Try NVIDIA
    if let Ok(output) = Command::new("nvidia-smi")
        .args(&["--query-gpu=memory.total", "--format=csv,noheader,nounits"])
        .output() {
        if output.status.success() {
            let s = String::from_utf8_lossy(&output.stdout);
            if let Ok(mb) = s.trim().parse::<f64>() {
                return ("nvidia".to_string(), mb / 1024.0);
            }
        }
    }

    // 2. Try AMD via sysfs
    if let Ok(entries) = fs::read_dir("/sys/class/drm") {
        for entry in entries.flatten() {
            let name = entry.file_name();
            if name.to_string_lossy().starts_with("card") {
                let mem_info_path = entry.path().join("device").join("mem_info_vram_total");
                if mem_info_path.exists() {
                    if let Ok(content) = fs::read_to_string(&mem_info_path) {
                        if let Ok(bytes) = content.trim().parse::<f64>() {
                            return ("amd".to_string(), bytes / (1024.0 * 1024.0 * 1024.0));
                        }
                    }
                }
            }
        }
    }

    // 3. Try glxinfo fallback
    if let Ok(output) = Command::new("glxinfo").arg("-B").output() {
        if output.status.success() {
            let s = String::from_utf8_lossy(&output.stdout);
            let mut vendor = "intel".to_string();
            if s.to_uppercase().contains("AMD") {
                vendor = "amd".to_string();
            } else if s.to_uppercase().contains("NVIDIA") {
                vendor = "nvidia".to_string();
            }
            for line in s.lines() {
                if line.contains("Dedicated video memory:") {
                    if let Some(mb_str) = line.split(':').nth(1) {
                        let clean: String = mb_str.chars().filter(|c| c.is_ascii_digit()).collect();
                        if let Ok(mb) = clean.parse::<f64>() {
                            return (vendor, mb / 1024.0);
                        }
                    }
                }
            }
        }
    }

    ("cpu".to_string(), 0.0)
}

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
