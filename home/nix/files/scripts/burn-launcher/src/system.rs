use sysinfo::System;

/// Helper function to check if the current system has enough physical RAM free.
pub fn get_system_ram_gb() -> (f32, f32) {
    let mut sys = System::new_all();
    sys.refresh_memory();
    let total_gb = sys.total_memory() as f32 / (1024.0 * 1024.0 * 1024.0);
    // Include swap or just physical? Let's do physical free + available
    let available_gb = sys.available_memory() as f32 / (1024.0 * 1024.0 * 1024.0);
    (total_gb, available_gb)
}

pub enum MemoryStatus {
    Safe,    // Full fit into free RAM
    Tight,   // Fits into total RAM but will require swapping/tight squeeze
    Unsafe,  // Exceeds total RAM! Do not run!
}

pub fn evaluate_memory(required_ram: Option<f32>) -> MemoryStatus {
    if let Some(req) = required_ram {
        let (total, free) = get_system_ram_gb();
        if req <= free {
            MemoryStatus::Safe
        } else if req <= total {
            MemoryStatus::Tight
        } else {
            MemoryStatus::Unsafe
        }
    } else {
        // If unspecified, safely assume it runs (standard model size heuristic)
        MemoryStatus::Safe
    }
}
