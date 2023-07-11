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

      # https://nixos.wiki/wiki/Wpa_supplicant
      # https://search.nixos.org/options?channel=22.11&show=networking.wireless.environmentFile
      environmentFile = "/home/${username}/.config/environment/wireless.env";

      # watch -n 3 wpa_cli status
      networks = {
        MAHDTech = {
          psk = "@PSK_HOME@";
          priority = 100;
          authProtocols = ["WPA-PSK"];
        };

        Horizon-VMware = {
          psk = "@PSK_WORK_CORP@";
          priority = 100;
          authProtocols = ["WPA-PSK"];
        };

        Lab-Wifi = {
          psk = "@PSK_WORK_LAB@";
          priority = 50;
          authProtocols = ["WPA-PSK"];
        };

        Belong518D40 = {
          psk = "@PSK_TOM_HOME_LAB@";
          priority = 50;
          authProtocols = ["WPA-PSK"];
        };

        Coldspot = {
          psk = "@PSK_COLDSPOT@";
          priority = 50;
          authProtocols = ["WPA-PSK"];
        };
      };
    };
  };
}
