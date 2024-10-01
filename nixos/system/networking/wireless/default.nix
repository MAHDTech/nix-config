{
  username,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [wpa_supplicant];

  networking = {
    wireless = {
      # Whether to enable wpa_supplicant
      enable = false;

      iwd = {
        # Whether to enable iwd
        enable = true;
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
          authProtocols = ["WPA-PSK"];
        };

        Coldspot = {
          pskRaw = "ext:psk_coldspot";
          priority = 50;
          authProtocols = ["WPA-PSK"];
        };
      };
    };
  };
}
