{ config, lib, ... }:

let
  apparmorPolicies = import ./policies { inherit config lib; };
in

{
  security.apparmor.policies = apparmorPolicies;
}
