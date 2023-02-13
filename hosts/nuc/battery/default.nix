{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

    ./notifier.nix

  ];

  environment.systemPackages = with pkgs; [

    libnotify

  ];

  services.batteryNotifier = {

    enable = true;

    notifyCapacity = 25;
    suspendCapacity = 5;

  };

}