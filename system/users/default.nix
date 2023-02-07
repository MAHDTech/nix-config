{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

    ./root
    ./mahdtech

  ];

  users.mutableUsers = false;

}