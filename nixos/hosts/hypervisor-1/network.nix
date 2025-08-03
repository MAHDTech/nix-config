{ pkgs, lib, ... }:
let

  # Default network configuration
  defaultNetworkConfig = {
    DHCP = "yes";
    DNSSEC = "yes";
    DNSOverTLS = "no";
    DNS = [ ];
    LinkLocalAddressing = "no";
  };

  # Default link configuration
  defaultLinkConfig = {
    RequiredForOnline = "routable";
  };

  # Default DHCP configuration
  defaultDhcpV4Config = {
    RouteMetric = 1000;
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
        anyInterface = lib.mkForce false; # Wait for ALL interfaces
        extraArgs = [
          "--interface=enp6s0" # Wait for Management
          "--interface=bond0" # Wait for Applications
        ];
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
          linkConfig = defaultLinkConfig;
          dhcpV4Config = lib.mergeAttrs defaultDhcpV4Config {
            # Set the management interface to a lower priority.
            RouteMetric = lib.mkForce 2000;
          };
          routes = [ ];
        };

        "101-enp1s0f0" = {
          matchConfig.Name = "enp1s0f0";
          networkConfig = {
            Bond = "bond0";
            DHCP = "no";
          };
          routes = [ ];
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
          networkConfig = lib.mergeAttrs defaultNetworkConfig {
            IPv4Forwarding = true;
            IPv6Forwarding = true;
          };
          linkConfig = lib.mergeAttrs defaultLinkConfig {
            MTUBytes = "9000";
          };
          dhcpV4Config = defaultDhcpV4Config;
          routes = [ ];
        };

      };

    };

  };

}
