{ config, lib, ... }:
let
  cfg = config.services.rustfs-managed;
  frontend = cfg.frontend.enable or false;
in
{
  imports = [
    ../nginx/graceful.nix
    (import ../nixos-drain/service-profile.nix {
      name = "rustfs";
      inherit (cfg) enable;
      units = [
        "rustfs-provision.timer"
        "rustfs-provision.service"
      ]
      ++ lib.optional frontend "nginx.service"
      ++ [ "rustfs.service" ];
    })
  ];
  systemd.services = lib.mkIf cfg.enable {
    rustfs.serviceConfig = {
      KillSignal = "SIGTERM";
      KillMode = "mixed";
      TimeoutStopSec = lib.mkForce "5min";
    };
    # During ordinary shutdown too, finish proxy requests before the backend exits.
    nginx = lib.mkIf frontend { after = [ "rustfs.service" ]; };
  };
}
