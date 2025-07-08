{ pkgs, ... }:
{

  #########################
  # NOTES
  #
  # - docs
  #   https://wiki.nixos.org/wiki/Incus
  #   https://nixos.wiki/wiki/Incus
  #
  # - Launch a container with:
  #   incus launch images:nixos/unstable nixos -c security.nesting=true
  #
  # - Launch a virtual machine with:
  #   incus launch --vm images:nixos/unstable nixos -c security.secureboot=false
  #########################

  imports = [ ];

  environment.systemPackages = with pkgs; [
  ];

  virtualisation = {
    incus = {
      enable = true;

      startTimeout = 600;
      socketActivation = false;
      softDaemonRestart = true;

      agent = {
        enable = false;
      };

      ui = {
        enable = true;
      };

      preseed = {
        networks = [
          {
            name = "incusbr0";
            type = "bridge";
            config = {
              "ipv4.address" = "192.168.100.1/24";
              "ipv4.nat" = "false";
            };
          }
        ];

        profiles = [
          {
            name = "default";
            devices = {
              eth0 = {
                name = "eth0";
                type = "nic";
                network = "incusbr0";
              };
              root = {
                path = "/";
                pool = "default";
                size = "25GiB";
                type = "disk";
              };
            };
          }
        ];

        storage_pools = [
          {
            name = "default";
            driver = "zfs";
            config = {
              source = "zpool/var/lib/incus/storage-pools/default";
            };
          }
        ];
      };
    };
  };

  networking = {
    nftables = {
      enable = true;
    };
  };
}
