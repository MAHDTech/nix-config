{ pkgs, lib, ... }:
{
  imports = [ ];

  services.fwupd = {
    enable = lib.mkDefault true;

    # Default to the standard system fwupd package
    package = lib.mkDefault pkgs.fwupd;

    # Sensible daemon settings
    daemonSettings = {
      # Disable test and invalid plugins by default
      DisabledPlugins = lib.mkDefault [
        "test"
        "invalid"
      ];

      # Allow host-specific device ignore lists
      DisabledDevices = lib.mkDefault [ ];
    };

    # UEFI Capsule Update Settings
    uefiCapsuleSettings = { };

    # Declarative extra remotes (e.g. lvfs-testing or custom enterprise remotes)
    extraRemotes = lib.mkDefault [ ];

    # Custom GPG keys for verifying updates
    extraTrustedKeys = lib.mkDefault [ ];
  };
}
