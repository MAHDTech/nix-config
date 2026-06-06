{ pkgs, ... }:

{
  imports = [
    ./htop
    ./nix-ld
  ];

  environment.systemPackages = with pkgs; [
    procps
  ];
}
