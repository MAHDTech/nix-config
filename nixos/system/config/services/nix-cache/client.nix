{ lib, ... }:
{
  nix.settings = {
    extra-substituters = [ "https://nix-cache.slopageddon.app?priority=10" ];
    substituters = [ "https://cache.nixos.org" ];
    connect-timeout = lib.mkDefault 5;
  };
}
