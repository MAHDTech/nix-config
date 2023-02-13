{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  services.acpid = {

    enable = false;

  };

}