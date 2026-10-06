{
  imports = [
    ../../system/config/services/nginx/graceful.nix
    (import ../../system/config/services/nixos-drain/service-profile.nix {
      name = "nginx-cache";
      units = [ "nginx.service" ];
      timeoutSeconds = 360;
    })
  ];
}
