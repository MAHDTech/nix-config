{ pkgs, ... }:
{
  # Snapdragon X Elite (ARM64) power management
  services = {
    # Override the battery device name to point to Snapdragon native path
    batteryNotifier.device = "qcom-battmgr-bat";
  };

  # zram swap for memory pressure relief
  # Laptop has 30 GiB RAM — zram gives ~60 GiB effective with zstd compression
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  # Limit CPU max frequency to prevent PMIC overcurrent resets under full 12-core load
  systemd.services.limit-cpu-freq = {
    description = "Limit CPU max frequency to prevent overcurrent crashes";
    before = [ "sysinit.target" ];
    wantedBy = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 1920000 | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq > /dev/null'";
      RemainAfterExit = true;
    };
  };
}
