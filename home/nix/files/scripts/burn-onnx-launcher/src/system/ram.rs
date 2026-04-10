/// Detect total and used system RAM in GB.
pub fn get_system_ram_gb() -> (f64, f64) {
    let mut sys = sysinfo::System::new();
    sys.refresh_memory();
    let total_ram_gb = sys.total_memory() as f64 / 1_073_741_824.0;
    let used_ram_gb = sys.used_memory() as f64 / 1_073_741_824.0;
    (total_ram_gb, used_ram_gb)
}
