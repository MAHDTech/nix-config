{ pkgs, ... }:

{
  imports = [
    ./htop
    ./nix-ld
  ];

  environment.systemPackages = with pkgs; [
    bubblewrap
    efibootmgr
    procps
  ];
}
