{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./fonts
    ./groups
    #./modules
    ./networking
    ./power
    ./programs
    ./secrets
    ./services
    ./users
    ./virtualisation
  ];

  environment.systemPackages = with pkgs; [];

  time.timeZone = "Australia/Canberra";

  i18n = {
    defaultLocale = "en_AU.UTF-8";

    supportedLocales = ["all" "en_AU.UTF-8/UTF-8" "en_AU/ISO-8859-1" "en_US.UTF-8/UTF-8"];

    extraLocaleSettings = {
      LANGUAGE = "en_AU";
      LANG = "en_AU.UTF-8";

      #LC_ALL = "en_AU.UTF-8";

      LC_ADDRESS = "en_AU.UTF-8";
      LC_COLLATE = "en_AU.UTF-8";
      LC_CTYPE = "en_AU.UTF-8";
      LC_IDENTIFICATION = "en_AU.UTF-8";
      LC_MEASUREMENT = "en_AU.UTF-8";
      LC_MESSAGES = "en_AU.UTF-8";
      LC_MONETARY = "en_AU.UTF-8";
      LC_NAME = "en_AU.UTF-8";
      LC_NUMERIC = "en_AU.UTF-8";
      LC_PAPER = "en_AU.UTF-8";
      LC_TELEPHONE = "en_AU.UTF-8";
      LC_TIME = "en_AU.UTF-8";
    };
  };

  nix = {
    enable = true;

    settings = {
      sandbox = true;

      trusted-users = ["root" "mahdtech"];
    };

    extraOptions = ''
      # Enable flakes
      experimental-features = nix-command flakes

      # Keep outputs and derivations during garbage-collect
      keep-outputs = true
      keep-derivations = true
    '';

    nixPath = ["nixpkgs=${inputs.nixpkgs}"];

    registry.nixpkgs.flake = inputs.nixpkgs;

    package = pkgs.nixStable;
    #package = pkgs.nixUnstable;
  };

  system.autoUpgrade = {
    enable = false;

    allowReboot = true;

    flake = "/home/mahdtech/Projects/GitHub/MAHDTech/nix-config";

    flags = ["--update-input" "nixpkgs" "--commit-lock-file"];

    dates = "00:00";
  };
}
