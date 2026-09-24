{ name, lib, ... }:
let
  fleet = (import ./fleet.nix).beszel;
  member = fleet.members.${name};
in
{
  imports = [ ../system/config/services/beszel/agent ];
  services.beszel.agent = {
    enable = true;
    environment.HUB_URL = lib.mkDefault fleet.url;
    opnix = {
      enable = true;
      publicKeyReference = lib.mkDefault fleet.publicKeyReference;
      tokenReference = lib.mkDefault member.tokenReference;
    };
  };
}
