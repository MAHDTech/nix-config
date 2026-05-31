{ lib, ... }:
{
  # Basic power management for Orion (desktop/SBC)
  services.power-profiles-daemon.enable = lib.mkForce true;
  services.tlp.enable = lib.mkForce false;

  # Override system-wide "performance" governor — schedutil is optimal for
  # the CIX P1 tri-cluster big.LITTLE architecture (4xA720 + 4xA720 + 4xA520).
  # PPD will manage governor switching dynamically (balanced/performance profiles).
  powerManagement.cpuFreqGovernor = lib.mkForce "schedutil";
}
