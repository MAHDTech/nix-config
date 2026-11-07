{ lib, ... }:
let
  upstreams = builtins.fromJSON (builtins.readFile ./upstreams.json);
in
{
  nix.settings = {
    extra-substituters = map (
      cache: "https://nix-cache.slopageddon.app${cache.prefix}?priority=10"
    ) upstreams;
    extra-trusted-public-keys = map (cache: cache.publicKey) upstreams ++ [
      # Copied store paths can retain their original cache's signature.
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    substituters = map (cache: "https://${cache.host}") upstreams;
    connect-timeout = lib.mkDefault 5;
  };
}
