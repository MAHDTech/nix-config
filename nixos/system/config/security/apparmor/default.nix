{ config, lib, ... }:

let
  apparmorPolicies = import ./policies { inherit config lib; };
in

{
  security = {
    apparmor = {
      enable = true;
      enableCache = false;
      includes = {
        "abstractions/base" = ''
          # Allow incus to execute wrapped binaries for image unpacking.
          /nix/store/**/.*-wrapped rix,
          /dev/tty rw,
        '';
      };
      killUnconfinedConfinables = false;
      packages = [ ];
      policies = apparmorPolicies;
    };
  };

  services = {
    dbus = {
      apparmor = "enabled";
    };
  };
}
