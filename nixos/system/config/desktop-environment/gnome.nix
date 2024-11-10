{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator

    gnome-tweaks

    ibus
  ];

  services.udev.packages = with pkgs; [gnome-settings-daemon];

  # If you need to run old GNOME 2 apps
  #services.dbus.packages = with pkgs; [ gnome2.GConf ];

  services.xserver = {
    enable = true;

    updateDbusEnvironment = true;

    displayManager = {gdm.enable = true;};

    desktopManager = {gnome.enable = true;};
  };

  environment.gnome.excludePackages =
    (with pkgs; [
      gnome-photos # photo viewer
      gnome-tour # welcome tour
    ])
    ++ (with pkgs; [
      atomix # puzzle game
      cheese # webcam tool
      epiphany # web browser
      evince # document viewer
      geary # email reader
      #gnome-gedit              # text editor
      gnome-characters # characters viewer
      gnome-music # music player
      #gnnome-terminal          # terminal
      hitori # sudoku game
      iagno # go game
      tali # poker game
      totem # video player
    ]);
}
