{ pkgs, lib, ... }:
{
  imports = [
  ];

  environment.systemPackages = with pkgs; [ ];

  #########################################################
  # Network Configuration
  #########################################################

  # Override the SOE configurations to only apply wired config to enp6s0
  systemd.network.networks."10-wired".matchConfig.Name = lib.mkForce "enp6s0";

  systemd = {

    network = {

      #########################################################
      # Network Devices
      #########################################################

      netdevs = {

        "100-bond0" = {
          netdevConfig = {
            Kind = "bond";
            Name = "bond0";
          };
          bondConfig = {
            Mode = "802.3ad";
            TransmitHashPolicy = "layer3+4";
          };
        };

      };

      #########################################################
      # Networks
      #########################################################

      networks = {

        "101-enp1s0f0" = {
          matchConfig.Name = "enp1s0f0";
          networkConfig.Bond = "bond0";
        };

        "102-enp1s0f1" = {
          matchConfig.Name = "enp1s0f1";
          networkConfig.Bond = "bond0";
        };

        "110-bond0" = {
          matchConfig.Name = "bond0";
          linkConfig = {
            RequiredForOnline = "carrier";
          };
          networkConfig = {
            LinkLocalAddressing = "no";
            DHCP = "ipv4";
          };
        };

      };

    };

  };

}
