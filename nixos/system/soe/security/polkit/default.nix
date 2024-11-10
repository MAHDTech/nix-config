{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  security.polkit = {
    enable = true;

    package = pkgs.polkit;

    extraConfig = "";

    debug = false;

    adminIdentities = [
      "unix-group:wheel"
    ];
  };
}
