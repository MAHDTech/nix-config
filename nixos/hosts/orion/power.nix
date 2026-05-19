{ lib, ... }:
{
  # Basic power management for Orion (desktop/SBC)
  services.power-profiles-daemon.enable = lib.mkForce true;
  services.tlp.enable = lib.mkForce false;

  # For ARM, schedutil is usually preferred over performance/powersave
  powerManagement.cpuFreqGovernor = lib.mkForce "schedutil";
}
