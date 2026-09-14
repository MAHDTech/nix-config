{ modulesPath, ... }:
{
  imports = [
    ./base.nix
    ./bootstrap.nix
    "${modulesPath}/virtualisation/disk-image.nix"
  ];
  # cloud-init supplies the unique hostname before selecting the flake host.
  networking.hostName = "";
  image.format = "raw";
  image.baseName = "nixos-github-runner-cloud";
  virtualisation.diskSize = 8192;

}
