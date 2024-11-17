{
  networking = {
    hostName = "KASMWEB-001";
    hostId = "def20001";
  };

  # KasmWeb configuration.
  # HACK: A quick and dirty test to get Kasm running to play with.
  # TODO: SOPS all the things!
  kasmwebconfig = {
    user = "kasm";
    redisPassword = "kasm";
    postgres = {
      user = "kasm";
      password = "kasm";
    };
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # Load system standard-operating-environment.
    ../../system/soe

    # System Configuration
    ../../system/config/fonts
    ../../system/config/zfs
    ../../system/config/theme/catppuccin

    # Kasm Workspaces Host.
    ../../system/config/services/kasmweb

    # Cloudflare Tunnel.
    ./cloudflared.nix

    # Headless

    # VMware virtualisation Guest.
    ../../system/config/virtualisation/guest/vmware
  ];
}
