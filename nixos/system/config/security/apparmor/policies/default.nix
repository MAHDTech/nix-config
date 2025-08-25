{
  config,
  lib,
  ...
}:

let

  #########################################################################
  # Imports
  #########################################################################

  policyDocker = import ./docker.nix;
  policyIncus = import ./incus.nix;

  #########################################################################
  # Policies
  #########################################################################

  enabledPolicies = [
    (lib.mkIf config.virtualisation.docker.enable policyDocker)
    (lib.mkIf config.virtualisation.incus.enable policyIncus)
  ];
  policies = lib.foldl (acc: policy: acc // policy) { } enabledPolicies;
in

policies
