{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [ ];

  networking = {
    wireless = {
      enable = false; # Disable wpa_supplicant

      iwd = {
        # Whether to enable iwd
        enable = true;
        settings = {
          General = {
            EnableNetworkConfiguration = true;
          };
          Network = {
            EnableIPv6 = true;
            RoutePriorityOffset = 300;
          };
          Settings = {
            AutoConnect = true;
          };
        };
      };

      userControlled = {
        enable = true;

        group = "wheel";
      };

      # https://search.nixos.org/options?channel=unstable&show=networking.wireless.secretsFile
      # Example secrets file contents:
      # psk_ssid_name=password_for_ssid_name
      secretsFile = "/run/secrets/wireless.conf";

      # watch -n 3 wpa_cli status
      networks = {
        MAHDTech = {
          pskRaw = "ext:psk_mahdtech";
          priority = 100;
          authProtocols = [ "WPA-PSK" ];
        };

        Coldspot = {
          pskRaw = "ext:psk_coldspot";
          priority = 50;
          authProtocols = [ "WPA-PSK" ];
        };
      };
    };
  };
}
