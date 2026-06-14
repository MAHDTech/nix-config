_: {
  # Snapdragon X Elite (ARM64) power management

  powerManagement.enable = true;

  # Override the battery device name to point to Snapdragon native path
  services.batteryNotifier.device = "qcom-battmgr-bat";

  # zram swap for memory pressure relief
  # Laptop has 30 GiB RAM — zram gives ~60 GiB effective with zstd compression
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100; # Prefer zram over any disk swap
  };
}
