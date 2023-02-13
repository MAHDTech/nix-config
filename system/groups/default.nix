{ config, lib, nixpkgs, pkgs, ... }:

{

  users.groups = {

    "plugdev" = {
      gid = 10000;
    };

  };

}