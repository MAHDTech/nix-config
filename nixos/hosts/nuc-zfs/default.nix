{
  imports = [
    ./hardware-configuration.nix

    # System defaults
    ../../system

    ./boot.nix
    ./audio.nix
    ./video.nix

    #./desktop/pantheon.nix
    #./desktop/gnome.nix
    ./desktop/cosmic.nix

    # Laptop
    ./battery
    ../../system/networking/wireless

    # Virtualization
    #../../system/virtualisation/host

    # Steam
    ../../system/programs/steam

    # macOS
    ../../system/programs/darling
  ];

  networking = {
    hostName = "nuc";
    hostId = "def00001";
  };
}
