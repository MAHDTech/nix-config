{ lib, ... }:
{
  # Basic power management for Orion (desktop/SBC)
  services.power-profiles-daemon.enable = lib.mkForce true;
  services.tlp.enable = lib.mkForce false;

  # Override system-wide "performance" governor — schedutil is optimal for
  # the CIX P1 tri-cluster big.LITTLE architecture (4xA720 + 4xA720 + 4xA520).
  # PPD will manage governor switching dynamically (balanced/performance profiles).
  powerManagement.cpuFreqGovernor = lib.mkForce "schedutil";

  # zram swap for memory pressure relief during NPU inference workloads
  # CONFIG_ZRAM=m is in the defconfig with ZSTD as default compressor
  # 100% of RAM: NPU model loads can spike memory significantly
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };
}
