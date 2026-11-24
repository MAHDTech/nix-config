{ lib, ... }:
let
  fleet = import ../fleet.nix;
  inherit (fleet) beszel;
in
{
  imports = [
    ../common/appliance.nix
    ../../system/config/services/beszel/hub
  ];
  services.beszel.hub = {
    enable = true;
    environment = {
      DISABLE_PASSWORD_AUTH = "true";
      USER_CREATION = "true";
      SHARE_ALL_SYSTEMS = "true";
      CHECK_UPDATES = "false";
      CONTAINER_DETAILS = "false";
    };
    systems = lib.mapAttrs (_: member: { inherit (member) host; }) beszel.members;
    opnix = {
      enable = true;
      privateKeyReference = "op://machines/Beszel Hub/private_key";
      bootstrapReference = "op://machines/Beszel Hub/bootstrap_environment";
      tokenReferences = lib.mapAttrs (_: member: member.tokenReference) beszel.members;
    };
    frontend = {
      enable = true;
      domain = "hub.${fleet.domain}";
      cloudflareTokenReference = fleet.acme.tokenReference;
      cloudflareEmail = fleet.acme.email;
    };
  };
}
