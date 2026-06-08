{
  # Basic power management for Orion (desktop/SBC)

  # Disable battery suspend timer since Orion has no battery
  systemd.timers."suspend-on-low-battery".enable = false;

  # zram swap for memory pressure relief during NPU inference workloads
  # CONFIG_ZRAM=m is in the defconfig with ZSTD as default compressor
  # 100% of RAM: NPU model loads can spike memory significantly
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  powerManagement = {
    cpuFreqGovernor = "performance";
  };
}
