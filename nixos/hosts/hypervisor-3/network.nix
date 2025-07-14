{ pkgs, lib, ... }:
{
  imports = [
  ];

  environment.systemPackages = with pkgs; [ ];

  #########################################################
  # Network Configuration
  #########################################################

  systemd = {

    network = {

      # Override the SOE to wait for all interfaces to come online.
      wait-online = {
        anyInterface = lib.mkForce false;
        timeout = 180;
      };

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

        # Override the SOE configurations to only apply wired config to enp6s0.
        "10-wired" = {
          matchConfig.Name = lib.mkForce "enp6s0";
          networkConfig = {
            DHCP = "yes";
            DNSSEC = "yes";
          };
        };

        "101-enp1s0f0" = {
          matchConfig.Name = "enp1s0f0";
          networkConfig = {
            Bond = "bond0";
            DHCP = "no";
          };
        };

        "102-enp1s0f1" = {
          matchConfig.Name = "enp1s0f1";
          networkConfig = {
            Bond = "bond0";
            DHCP = "no";
          };
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
