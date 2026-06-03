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

  #########################################################################
  # Policies
  #########################################################################

  enabledPolicies = [
    (lib.mkIf config.virtualisation.docker.enable policyDocker)
  ];
  policies = lib.foldl (acc: policy: acc // policy) { } enabledPolicies;
in

policies
