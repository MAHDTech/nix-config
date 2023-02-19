{ pkgs, lib, ... }:

with lib;

{

  pre-commit.hooks = {
    black.enable = true;
    isort.enable = true;
  };

  packages = with pkgs; [

    nixpkgs-fmt

  ];

}