{
  inputs,
  pkgs,
  ...
}:
{
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

    # AGS / Astal
    inputs.ags.packages.${pkgs.system}.astal3
    inputs.ags.packages.${pkgs.system}.astal4
    inputs.ags.packages.${pkgs.system}.io

    # Matugen
    inputs.matugen.packages.${pkgs.system}.default

    # Marble
    gjs

    # Epik
    esbuild
  ];

  programs.ags = {
    enable = true;

    configDir = ../../../files/ags/config;

    extraPackages = with pkgs; [
      # Astal Libraries
      # https://aylur.github.io/astal/guide/libraries/references#astal-libraries

      # Apps: Library and cli tool for querying applications
      inputs.ags.packages.${pkgs.system}.apps

      # Auth: Authentication library using PAM
      inputs.ags.packages.${pkgs.system}.auth

      # Battery: DBus proxy library for upower daemon
      inputs.ags.packages.${pkgs.system}.battery

      # Bluetooth: Library to control bluez over dbus
      inputs.ags.packages.${pkgs.system}.bluetooth

      # Cava: Audio visualizer library using cava
      #inputs.ags.packages.${pkgs.system}.cava

      # Greet: Library and CLI tool for sending requests to greetd
      inputs.ags.packages.${pkgs.system}.greet

      # Hyprland: Library and cli tool for Hyprland IPC socket
      inputs.ags.packages.${pkgs.system}.hyprland

      # MPRIS: Library and cli tool for controlling media players
      inputs.ags.packages.${pkgs.system}.mpris

      # Network: Wrapper library
      inputs.ags.packages.${pkgs.system}.network

      # Notifd: A notification daemon library and cli tool
      inputs.ags.packages.${pkgs.system}.notifd

      # Powerprofiles: Library and cli to control upowerd powerprofiles
      inputs.ags.packages.${pkgs.system}.powerprofiles

      # River: Library and cli tool for getting status information of the river wayland compositor
      inputs.ags.packages.${pkgs.system}.river

      # Tray: A systemtray library and cli tool
      inputs.ags.packages.${pkgs.system}.tray

      # Wireplumber: A library for audio control using wireplumber
      inputs.ags.packages.${pkgs.system}.wireplumber
    ];
  };
}
