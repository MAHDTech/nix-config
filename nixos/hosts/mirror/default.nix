{ pkgs, ... }:
let
  fleet = import ../fleet.nix;
  domain = "mirror.${fleet.domain}";
in
{
  imports = [
    ../common/appliance.nix
    ../../system/config/services/internal-https
    ./web.nix
    ./drain.nix
  ];

  services.internal-https = {
    enable = true;
    domains = [ domain ];
    cloudflareTokenReference = fleet.acme.tokenReference;
    cloudflareEmail = fleet.acme.email;
    certificateGroup = "caddy";
    reloadServices = [ "caddy.service" ];
    enableNginxCatchAll = false;
  };

  environment.systemPackages = [ pkgs.rsync ];
}
