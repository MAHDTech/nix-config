{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.ags.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    #wf-recorder
    brightnessctl
    bun
    dart-sass
    fd
    #gtk3
    hyprpicker
    networkmanager
    pavucontrol
    slurp
    swappy
    swww
    wayshot
    wl-clipboard

    # Astal
    inputs.ags.packages.${pkgs.system}.io
    inputs.matugen.packages.${pkgs.system}.default
  ];

  programs.ags = {
    enable = true;
    configDir = ../../files/ags/config;
    extraPackages = with pkgs; [
      # Library and cli tool for querying applications
      inputs.ags.packages.${pkgs.system}.apps
      # Authentication library using PAM
      inputs.ags.packages.${pkgs.system}.auth
      # DBus proxy library for upower daemon
      inputs.ags.packages.${pkgs.system}.battery
      # Library to control bluez over dbus
      inputs.ags.packages.${pkgs.system}.bluetooth
      # Audio visualizer library using cava
      #inputs.ags.packages.${pkgs.system}.cava
      # Library and CLI tool for sending requests to greetd
      inputs.ags.packages.${pkgs.system}.greet
      # Library and cli tool for Hyprland IPC socket
      inputs.ags.packages.${pkgs.system}.hyprland
      # Library and cli tool for controlling media players
      inputs.ags.packages.${pkgs.system}.mpris
      # NetworkManager wrapper library
      inputs.ags.packages.${pkgs.system}.network
      # A notification daemon library and cli tool
      inputs.ags.packages.${pkgs.system}.notifd
      # Library and cli to control upowerd powerprofiles
      inputs.ags.packages.${pkgs.system}.powerprofiles
      # Library and cli tool for getting status information of the river wayland compositor
      inputs.ags.packages.${pkgs.system}.river
      # A systemtray library and cli tool
      inputs.ags.packages.${pkgs.system}.tray
      # A library for audio control using wireplumber
      inputs.ags.packages.${pkgs.system}.wireplumber
    ];
  };
}
