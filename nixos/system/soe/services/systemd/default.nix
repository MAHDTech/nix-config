{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./oomd.nix
  ];

  environment.systemPackages = with pkgs; [ ];

  systemd = {
    extraConfig = ''
      DefaultTimeoutStartSec=15s
      DefaultTimeoutStopSec=15s
      DefaultLimitNOFILE=1048576
    '';

    timers.suspend-on-low-battery = {
      wantedBy = [ "multi-user.target" ];

      timerConfig = {
        OnUnitActiveSec = "120";
        OnBootSec = "120";
      };
    };

    network = {
      enable = true;

      wait-online = {
        enable = true;
        anyInterface = lib.mkDefault true;
        timeout = lib.mkDefault 120;
        extraArgs = lib.mkDefault [ ];
      };

      config = { };

      networks =
        let

          defaultNetworkConfig = {
            DHCP = "yes";
            DNSSEC = "yes";
            DNSOverTLS = "no";
            DNS = [ ];
            LinkLocalAddressing = "no";
          };

          defaultWiredLinkConfig = {
            RequiredForOnline = "routable";
          };

          defaultWirelessLinkConfig = {
            RequiredForOnline = "carrier";
          };
        in
        {
          # systemd-networkd handles LAN
          "10-wired" = {
            enable = true;
            name = "en*";

            networkConfig = defaultNetworkConfig;
            linkConfig = defaultWiredLinkConfig;

            dhcpV4Config.RouteMetric = 1000;
          };

          # NetworkManager handles WiFi
          "20-wireless" = {
            enable = false;
            name = "wl*";

            networkConfig = defaultNetworkConfig;
            linkConfig = defaultWirelessLinkConfig;

            dhcpV4Config.RouteMetric = 2000;
          };

          # systemd-networkd handles tunnel interfaces
          "30-tunnel" = {
            enable = true;
            name = "tun*";

            networkConfig = defaultNetworkConfig;

            linkConfig.Unmanaged = true;
          };

          "40-bluetooth" = {
            enable = true;
            name = "bn*";

            networkConfig = defaultNetworkConfig;
            linkConfig = defaultWirelessLinkConfig;

            dhcpV4Config.RouteMetric = 3000;
          };

          # 50-tailscale (managed by Tailscale)

          # 80-iwd (managed by iwd)

          # 100-bonded (managed by systemd-networkd per-host)
        };
    };

    targets = {
      sleep = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };

      suspend = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };

      hibernate = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };

      "hybrid-sleep" = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
    };
  };
}
