{ lib, ... }:

let

  #########################################################################
  # Imports
  #########################################################################

  policyIncus = import ./incus.nix;
  policyDocker = import ./docker.nix;

  #########################################################################
  # Policies
  #########################################################################

  mergedPolicies = [
    policyIncus
    policyDocker
  ];
  policies = lib.foldl (acc: policy: acc // policy) { } mergedPolicies;
in

policies
