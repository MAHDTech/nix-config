use std::process::Command;
use std::fs;

/// Detect GPU vendor and total VRAM in GB.
///
/// Detection order:
/// 1. NVIDIA via `nvidia-smi`
/// 2. AMD via `/sys/class/drm` sysfs
/// 3. Intel/other via `glxinfo` fallback
/// 4. Falls back to ("cpu", 0.0) if no GPU detected
pub fn get_gpu_vendor_and_vram() -> (String, f64) {
    // 1. Try NVIDIA
    if let Ok(output) = Command::new("nvidia-smi")
        .args(["--query-gpu=memory.total", "--format=csv,noheader,nounits"])
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
