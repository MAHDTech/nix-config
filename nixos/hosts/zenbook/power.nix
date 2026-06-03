{ lib, ... }:
{
  # Snapdragon X Elite (ARM64) power management
  services = {

    power-profiles-daemon.enable = lib.mkForce true;
    tlp.enable = lib.mkForce false;

    # Override the battery device name to point to Snapdragon native path
    batteryNotifier.device = "qcom-battmgr-bat";
  };

  # For ARM, schedutil is usually preferred over performance/powersave
  powerManagement.cpuFreqGovernor = lib.mkForce "schedutil";

}
