{
  pkgs,
  ...
}:
{
  imports = [
    # Hardware specific config
    ./hardware-configuration.nix
    ./pd-mapper.nix

    # Generic installer base
    ../../system/installer/base.nix
    ../../system/installer/raw-efi-image.nix
  ];

  boot.initrd = {
    # Prepend a CPIO archive containing DSP firmware into the initrd.
    # This is critical for Zenbook to see WiFi/BT during installation.
    prepend = [
      "${pkgs.runCommand "zenbook-firmware-initrd"
        {
          nativeBuildInputs = [
            pkgs.cpio
            pkgs.zstd
          ];
        }
        ''
          mkdir -p staging/lib/firmware
          cp -r ${pkgs.callPackage ./firmware.nix { }}/lib/firmware/* staging/lib/firmware/
          cd staging
          find . -print0 | cpio --null -oH newc --quiet | zstd > $out
        ''
      }"
    ];
  };

  networking.hostName = "installer-zenbook";
  networking.hostId = "def00003";

  # Ensure the installer is as minimal as possible but has what we need
  services.openssh.enable = true;
}
