{ pkgs, ... }:
{
  # https://linrunner.de/tlp/settings/processor.html

  imports = [ ];

  environment.systemPackages = with pkgs; [ ];

  # Disable power-profiles-daemon
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;

    settings = {
      USB_AUTOSUSPEND = 0;

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;

      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "passive";

      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "ondemand";

      CPU_ENERGY_PERF_POLICY_ON_AC = "";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

      # CPU Performance (AC)
      CPU_MIN_PERF_ON_AC = 100;
      CPU_MAX_PERF_ON_AC = 100;

      # CPU Performance (BAT)
      CPU_MIN_PERF_ON_BAT = 25;
      CPU_MAX_PERF_ON_BAT = 75;

      # Start charging when the battery hits this level.
      START_CHARGE_THRESH_BAT0 = 75;

      # Stop charging when the battery hits this level.
      STOP_CHARGE_THRESH_BAT0 = 81;

      # Enable audio power saving for Intel HDA, AC97 devices (timeout in secs).
      # A value of 0 disables, >=1 enables power saving (recommended: 1).
      # Default: 0 (AC), 1 (BAT)
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 1;

      # Runtime Power Management for PCI(e) bus devices: on=disable, auto=enable.
      # Default: on (AC), auto (BAT)
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # Battery feature drivers: 0=disable, 1=enable
      # Default: 1 (all)
      NATACPI_ENABLE = 1;
      TPACPI_ENABLE = 1;
      TPSMAPI_ENABLE = 1;
    };
  };
}
