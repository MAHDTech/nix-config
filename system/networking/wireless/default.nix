{ username, config, lib, nixpkgs, pkgs, ... }:

{

  environment.systemPackages = with pkgs; [

    wpa_supplicant

  ];

  networking = {

    wireless = {

      enable = true;

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

        };

        Horizon-VMware = {

            psk = "@PSK_WORK_CORP@";

        };

      };

    };

  };

}
