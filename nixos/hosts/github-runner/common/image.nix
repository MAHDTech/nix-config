{ self, ... }:
{
  imports = [
    ./base.nix
    ./bootstrap.nix
  ];

  networking.hostName = "";
  virtualisation.diskSize = 16384;

  image.modules.qemu-efi = {
    image.baseName = "nixos";
  };

  # Preload the runner closures without registering the image to any runner or group.
  system.extraDependencies = [
    self.nixosConfigurations.github-runner-01.config.system.build.toplevel
    self.nixosConfigurations.github-runner-06.config.system.build.toplevel
  ];
}
