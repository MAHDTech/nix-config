{ config, pkgs, nixpkgs, lib, ... }:

{

  imports = [

  ];

  time.timeZone = "Australia/Canberra";

  i18n.defaultLocale = "en_US.UTF-8";

  users.mutableUsers = false;

  users.users.root = {

    shell = pkgs.bash;

    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$Ashin4XGbqsek1XL$GwZv0fSwABFuSgbb0QW.duASESVUFTg.9vbqC4B/HZ3dwNpiwmCcgLOYiQZiFS9qUmZUXsfjTcvpOpK0wGkkp1";

  };

  users.users.mahdtech = {

    uid = 1000;
    isNormalUser = true;
    createHome = true;
    home = "/home/mahdtech";
    shell = pkgs.bash;

    # mkpasswd --method=SHA-512 --stdin
    initialHashedPassword = "$6$0fQUL.dlpw4kaVRc$/cbRiuWeR5Pu9yc7uvF2sktWtGOtTjtXviU.mAtWZlOwURJ0Ld1Ccxo5K9yiQ7LqPMU3NCcGGrk3Q7jmiFgS21";

    extraGroups = [
      "wheel"
      "docker"
      "video"
      "audio"
      "disk"
      "networkmanager"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
    ];

  };

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

    nixPath = [ "nixpkgs=${nixpkgs}" ];
    registry.nixpkgs.flake = nixpkgs;
    package = pkgs.nixUnstable;

  };

  nixpkgs.config.allowUnfree = true;

  #sops.defaultSopsFile = ./secrets.yaml;

  services.sshd.enable = true;

  services.gnome.gnome-keyring.enable = true;

}
