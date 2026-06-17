{ pkgs, ... }:
let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.pillow ]);
  oledScript = ./oled-manager.py;
in
{
  systemd.services.oled-manager = {
    description = "CloudKey OLED Screen Manager";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pythonEnv}/bin/python3 ${oledScript}";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
