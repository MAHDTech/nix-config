{ config, lib, ... }:
let
  cfg = config.services.beszel.hub;
in
{
  imports = [
    ../../nginx/graceful.nix
    (import ../../nixos-drain/service-profile.nix {
      name = "beszel-hub";
      inherit (cfg) enable;
      # Shut down PocketBase first so persistent streams do not pin Nginx workers.
      units = [ "beszel-hub.service" ] ++ lib.optional cfg.frontend.enable "nginx.service";
    })
  ];
  systemd.services.beszel-hub = lib.mkIf cfg.enable {
    after = lib.optional cfg.frontend.enable "nginx.service";
    serviceConfig = {
      KillSignal = "SIGTERM";
      KillMode = "mixed";
      TimeoutStopSec = "5min";
    };
  };
}
