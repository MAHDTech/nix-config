{ inputs, config, lib, pkgs, ... }:

let

in {

  imports = [

  ];

  environment.systemPackages = with pkgs; [

    gnomeExtensions.appindicator

    gnome.gnome-tweaks

    ibus

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

    };

    desktopManager = {

      gnome.enable = true;

    };

  };

  environment.gnome.excludePackages = (with pkgs; [

    gnome-photos                # photo viewer
    gnome-tour                  # welcome tour

  ]) ++ (with pkgs.gnome; [

    atomix                      # puzzle game
    cheese                      # webcam tool
    epiphany                    # web browser
    evince                      # document viewer
    geary                       # email reader
    #gedit                       # text editor
    gnome-characters
    gnome-music                 # music player
    #gnome-terminal              # terminal
    hitori                      # sudoku game
    iagno                       # go game
    tali                        # poker game
    totem                       # video player

  ]);

}
