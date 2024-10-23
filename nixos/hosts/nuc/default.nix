{
  networking = {
    hostName = "NUC";
    hostId = "def00001";
  };

  imports = [
    # Load device specific hardware configuration.
    ./hardware-configuration.nix

    # Load defaults for all systems.
    ../../system

    # Load device specific configurations.
    ./audio.nix
    ./bluetooth.nix
    ./boot.nix
    ./packages.nix
    ./video.nix

    # Load the chosen desktop environment.
    #../../system/desktop/cosmic.nix
    #../../system/desktop/gnome.nix
    #../../system/desktop/pantheon.nix
    ../../system/desktop/hyprland.nix

    # Laptop specific configurations.
    ../../system/laptop
    ../../system/networking/wireless

    # Virtualization
    ../../system/virtualisation/host

    # Steam
    #../../system/programs/steam
  ];
}
