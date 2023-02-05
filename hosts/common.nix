{ config, pkgs, nixpkgs, lib, ... }:

{

  imports = [

  ];

  time.timeZone = "Australia/Canberra";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.mahdtech = {
    isNormalUser = true;
    createHome = true;
    extraGroups =
      [
        "wheel"
        "docker"
        "video"
        "audio"
        "disk"
        "networkmanager"
      ];
    home = "/home/mahdtech";
    uid = 1000;
    shell = pkgs.bash;
  };

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    nixPath = [ "nixpkgs=${nixpkgs}" ];
    registry.nixpkgs.flake = nixpkgs;
    package = pkgs.nixUnstable;
  };

  #sops.defaultSopsFile = ./secrets.yaml;

}