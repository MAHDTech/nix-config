{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

    ./hardware-configuration.nix

    ../common.nix

    ./boot.nix
    #./audio.nix
    #./video.nix
    ./desktop-environment.nix

  ];

  system.stateVersion = "22.11";

  networking = {
    hostName = "nuc";
    hostId = "b63f2c0e";
  };

  powerManagement = {
    powertop.enable = true;
    cpuFreqGovernor = "performance";
  };

  # Taken from https://gitlab.com/xaverdh/my-nixos-config/-/blob/master/per-box/tux/default.nix
  #systemd.timers.suspend-on-low-battery = {
  #  wantedBy = [ "multi-user.target" ];
  #  timerConfig = {
  #    OnUnitActiveSec = "120";
  #    OnBootSec= "120";
  #  };
  #};

  systemd.extraConfig = ''
    DefaultTimeoutStopSec=10s
  '';

  #systemd.services.suspend-on-low-battery =
  #  let
  #    battery-level-sufficient = pkgs.writeShellScriptBin
  #      "battery-level-sufficient" ''
  #      test "$(cat /sys/class/power_supply/BAT0/status)" != Discharging \
  #        || test "$(cat /sys/class/power_supply/BAT0/capacity)" -ge 5
  #    '';
  #  in
  #    {
  #      serviceConfig = { Type = "oneshot"; };
  #      onFailure = [ "suspend.target" ];
  #      script = "${lib.getExe battery-level-sufficient}";
  #    };

  #services.throttled.enable = true;

  #programs.nm-applet.enable = true;

  #programs.gnupg.agent = {
  #  enable = true;
  #  enableSSHSupport = true;
  #};

  #services.dbus.enable = true;

  #security.rtkit.enable = true;

  #xdg.portal = {
  #  enable = true;
  #  wlr.enable = true;
  #  extraPortals = with pkgs; [
  #    xdg-desktop-portal-gtk
  #    xdg-desktop-portal-wlr
  #  ];
  #};

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;

  #boot.kernelParams = [

    # Reference: https://wiki.archlinux.org/title/intel_graphics
    #"options i915 enable_guc=1"

  #];

  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
  ];

  #services.autorandr = { enable = true; };

  #services.udev.extraRules = ''
  #  ATTRS{idVendor}=="27b8", ATTRS{idProduct}=="01ed", MODE:="666", GROUP="plugdev"
  #'';

  hardware.opengl = {

    enable = true;

    extraPackages = with pkgs; [

      intel-media-driver
      libvdpau-va-gl
      vaapiIntel
      vaapiVdpau

    ];

  };

  #environment.variables = {
  #  VDPAU_DRIVER = "va_gl";
  #  LIBVA_DRIVER_NAME = "iHD";
  #};

  #fonts.fonts = with pkgs; [ font-awesome iosevka aileron ];

  #environment.systemPackages = with pkgs; [
  #  intel-gpu-tools
  #  vdpauinfo
  #  wayland
  #];

  #services.cron.enable = true;

  #virtualisation = {

  #  docker = {

  #    enable = true;

  #    #storageDriver = "overlay2";
  #    storageDriver = "zfs";

  #    rootless = {

  #      enable = true;

  #      setSocketVariable = true;

  #    };

  #  };

  #  virtualbox.host.enable = false;

  #};

  #networking.firewall = {
  #  enable = true;
  #  trustedInterfaces = [ "docker0" ];
  #  allowedTCPPorts = [ 17500 ];
  #  allowedUDPPorts = [ 17500 ];
  #};

}
