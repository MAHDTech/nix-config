{ lib, ... }:
{
  # Basic power management for Orion (desktop/SBC)
  services.power-profiles-daemon.enable = lib.mkForce true;
  services.tlp.enable = lib.mkForce false;

  # We omit forcing cpuFreqGovernor here because 'schedutil' is often compiled
  # directly into the kernel on ARM SBCs (built-in instead of a module).
  # Forcing it causes systemd-modules-load to complain when it can't find 'cpufreq_schedutil.ko'.
}
