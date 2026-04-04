{ lib, ... }:
{
  # Snapdragon X Elite (ARM64) power management
  services.power-profiles-daemon.enable = true;
  
  # For ARM, schedutil is usually preferred over performance/powersave
  powerManagement.cpuFreqGovernor = lib.mkForce "schedutil";

  # Thermald isn't usually helpful for Snapdragon yet, 
  # but ensuring power-profiles-daemon is active covers most cases.
}
