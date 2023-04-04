{
  config,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  systemd = {
    extraConfig = ''
      DefaultTimeoutStartSec=15s
      DefaultTimeoutStopSec=15s
      DefaultLimitNOFILE=1048576
    '';

    timers.suspend-on-low-battery = {
      wantedBy = ["multi-user.target"];

      timerConfig = {
        OnUnitActiveSec = "120";
        OnBootSec = "120";
      };
    };

    network = {
      enable = true;

      wait-online = {
        anyInterface = true;
        timeout = 120;
        extraArgs = [];
      };

      config = {};

      networks = let
        networkConfig = {
          DHCP = "yes";
          DNSSEC = "yes";
          DNSOverTLS = "no";

          DNS = [];
        };
      in {
        "40-wired" = {
          enable = true;
          name = "en*";

          inherit networkConfig;

          dhcpV4Config.RouteMetric = 1000;
        };

        "40-wireless" = {
          enable = true;
          name = "wl*";

          inherit networkConfig;

          dhcpV4Config.RouteMetric = 2000;
        };

        "40-tunnel" = {
          enable = true;
          name = "tun*";

          inherit networkConfig;

          linkConfig.Unmanaged = true;
        };

        "40-bluetooth" = {
          enable = true;
          name = "bn*";

          inherit networkConfig;

          dhcpV4Config.RouteMetric = 3000;
        };
      };
    };
  };

  services = {
    /*
    # Wait for any interface to come online.
    systemd-networkd-wait-online = {

      serviceConfig = {

        ExecStart = [

          ""
          "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --any"

        ];

      };

    };
    */
  };
}
