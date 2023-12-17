{
  imports = [
    ./hardware-configuration.nix

    # System defaults
    ../../system

    ./boot.nix
    ./audio.nix
    ./video.nix

    #./desktop/cosmic.nix
    #./desktop/pantheon.nix
    #./desktop/gnome.nix

    # Laptop
    ./battery
    ../../system/networking/wireless

    # Virtualization
    #../../system/virtualisation/host

    # Steam
    #../../system/programs/steam
  ];

  networking = {
    hostName = "nuc";
    hostId = "def00001";
  };
}
