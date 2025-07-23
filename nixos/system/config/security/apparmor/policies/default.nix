{ lib, ... }:

let

  #########################################################################
  # Imports
  #########################################################################

  policyDocker = import ./docker.nix;
  policyIncus = import ./incus.nix;

  #########################################################################
  # Policies
  #########################################################################

  mergedPolicies = [
    policyDocker
    policyIncus
  ];
  policies = lib.foldl (acc: policy: acc // policy) { } mergedPolicies;
in

policies
