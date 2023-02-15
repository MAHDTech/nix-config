{ config, lib, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  programs.seahorse = {

    enable = true;

  };

}