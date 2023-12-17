{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [
    cosmic-applets
    cosmic-comp
    cosmic-edit
    cosmic-greeter
    cosmic-icons
    cosmic-panel
    cosmic-settings
    gnome.gnome-tweaks
    gnomeExtensions.appindicator
    ibus
  ];

  services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];

  services.xserver = {
    enable = true;

    updateDbusEnvironment = true;

    displayManager = {
      gdm = {
        enable = true;
        wayland = true;
      };
      defaultSession = "gnome";
      #defaultSession = "cosmic";
      sessionPackages = [
      ];
    };

    desktopManager = {
      gnome = {
        enable = true;
      };
    };
  };

  environment.gnome.excludePackages =
    (with pkgs; [
      gnome-photos # photo viewer
      gnome-tour # welcome tour
    ])
    ++ (with pkgs.gnome; [
      atomix # puzzle game
      cheese # webcam tool
      epiphany # web browser
      evince # document viewer
      geary # email reader
      #gedit                       # text editor
      gnome-characters
      gnome-music # music player
      #gnome-terminal              # terminal
      hitori # sudoku game
      iagno # go game
      tali # poker game
      totem # video player
    ]);
}
