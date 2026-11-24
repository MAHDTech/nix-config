{ pkgs, ... }:
let
  fleet = import ../fleet.nix;
  domain = "nix-cache.${fleet.domain}";
in
{
  imports = [
    ../common/appliance.nix
    ../../system/config/services/internal-https
    ./proxy.nix
    ./drain.nix
  ];

  services = {
    internal-https = {
      enable = true;
      domains = [ domain ];
      cloudflareTokenReference = fleet.acme.tokenReference;
      cloudflareEmail = fleet.acme.email;
    };
    nginx.virtualHosts.${domain} = {
      onlySSL = true;
      useACMEHost = domain;
    };
  };

  environment.systemPackages = [
    pkgs.curl
    pkgs.jq
  ];
}
