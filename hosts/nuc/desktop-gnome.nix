{ config, lib, nixpkgs, pkgs, ... }:

let

in {

  imports = [

  ];

  environment.systemPackages = with pkgs; [

    gnomeExtensions.appindicator

  ];

  services.udev.packages = with pkgs; [

    gnome.gnome-settings-daemon

  ];

  # If you need to run old GNOME 2 apps
  #services.dbus.packages = with pkgs; [ gnome2.GConf ];

  services.xserver = {

    enable = true ;

    updateDbusEnvironment = true;

    displayManager = {

      gdm.enable = true;
      gnome.enable = true;

      autologin.enable = false;
      autologin.user = "user";

    };

  };

  environment.gnome.excludePackages = (with pkgs; [

    gnome-photos
    gnome-tour

  ]) ++ (with pkgs.gnome; [

    cheese                 # webcam tool
    gnome-music            # music player
    #gnome-terminal         # terminal
    #gedit                  # text editor
    epiph                   # web browser
    geary                   # email reader
    evinc                   # document viewer
    #gnome-characters
    totem                   # video player
    tali                    # poker game
    iagno                   # go game
    hitori                  # sudoku game
    atomix                  # puzzle game

  ]);

}
