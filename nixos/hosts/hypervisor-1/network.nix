{ pkgs, lib, ... }:
let

  defaultNetworkConfig = {
    DHCP = "yes";
    DNSSEC = "yes";
    DNSOverTLS = "no";
    DNS = [ ];
    LinkLocalAddressing = "yes";
  };

in
{
  imports = [
  ];

  environment.systemPackages = with pkgs; [ ];

  #########################################################
  # Network Configuration
  #########################################################

  systemd = {

    network = {

      wait-online = {
        enable = true;
        timeout = lib.mkForce 180;
        extraArgs = [ ];
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
        # which is the management interface.
        "10-wired" = {
          matchConfig.Name = lib.mkForce "enp6s0";
          networkConfig = defaultNetworkConfig;
          dhcpV4Config = {
            RouteMetric = 1000;
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
          networkConfig = defaultNetworkConfig;
          dhcpV4Config = {
            RouteMetric = 2000; # Lower priority.
          };
          routes = [
            # Reach incus routed networks via incusbr1
            {
              Destination = "10.10.201.0/24";
              Gateway = "10.10.201.1";
              Metric = 1000;
            }
          ];
        };

      };

    };

  };

}
