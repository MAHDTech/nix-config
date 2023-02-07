{ config, pkgs, nixpkgs, lib, ... }:

{

  imports = [

    #./modules
    ./networking
    ./power
    ./programs
    #./secrets # TODO: Finish sops-nix
    ./services
    ./users
    ./virtualisation

  ];

  environment.systemPackages = with pkgs; [

  ];

  time.timeZone = "Australia/Canberra";

  i18n.defaultLocale = "en_US.UTF-8";

  nix = {

    enable = true;

    settings = {

      sandbox = true;

      trusted-users = [

        "root"
        "mahdtech"

      ];

    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    nixPath = [
      "nixpkgs=${nixpkgs}"
    ];

    registry.nixpkgs.flake = nixpkgs;

    package = pkgs.nixStable;
    #package = pkgs.nixUnstable;

  };

  nixpkgs.config = {

    allowUnfree = true ;

  };

  system.autoUpgrade = {

    enable = false;

    allowReboot = true;

    flake = "/home/mahdtech/Projects/GitHub/MAHDTech/nix-config";
    flags = [
      "--update-input"
      "nixpkgs"
      "--commit-lock-file"
    ];

    dates = "17:30";

  };

}
