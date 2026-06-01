{ lib, ... }:
{
  # Snapdragon X Elite (ARM64) power management
  services.power-profiles-daemon.enable = lib.mkForce true;
  services.tlp.enable = lib.mkForce false;

  # For ARM, schedutil is usually preferred over performance/powersave
  powerManagement.cpuFreqGovernor = lib.mkForce "schedutil";
}
