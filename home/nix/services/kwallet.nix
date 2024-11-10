{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      kwalletcli
      kdePackages.kwallet
      kdePackages.kwallet-pam
      kdePackages.kwalletmanager
      kdePackages.ksshaskpass
      kdePackages.signon-kwallet-extension
    ];
  };

  xdg = {
    dataFile = {
      "kwallet.service" = {
        target = "dbus-1/services/kwallet.service";

        text = ''
          [D-BUS Service]
          Name=org.kde.kwalletd5
          Exec=${pkgs.kdePackages.kwallet}/bin/kwalletd6
        '';
      };
    };
  };
}
