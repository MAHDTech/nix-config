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
    ./boot.nix
    ./audio.nix
    ./video.nix
    ./packages.nix

    # Load the chosen desktop environment.
    ./desktop/cosmic.nix
    #./desktop/gnome.nix
    #./desktop/pantheon.nix

    # Laptop specific configurations.
    ./laptop
    ../../system/networking/wireless

    # Virtualization
    ../../system/virtualisation/host

    # Steam
    #../../system/programs/steam
  ];
}
