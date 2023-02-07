{ config, lib, nixpkgs, pkgs, ... }:

{

  networking = {

    wireless = {

      enable = false;

      userControlled = {

        enable = true;

        group = "wheel";

      };

    };

  };

}