{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [ ];

  security.polkit = {
    enable = true;

    package = pkgs.polkit;

    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.fwupd.refresh-remote" ||
          action.id == "org.freedesktop.fwupd.get-remotes") &&
          subject.user == "fwupd-refresh") {
          return polkit.Result.YES;
        }
      });
    '';

    debug = false;

    adminIdentities = [
      "unix-group:wheel"
    ];
  };
}
