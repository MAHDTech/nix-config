{ config, lib, ... }:

let
  apparmorPolicies = import ./policies { inherit config lib; };
in

{
  security = {
    apparmor = {
      enable = true;
      enableCache = false;
      includes = { };
      killUnconfinedConfinables = false;
      packages = [
      ];
      policies = apparmorPolicies;
    };
  };

  services = {
    dbus = {
      apparmor = "enabled";
    };
  };
}
