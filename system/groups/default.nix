{ config, lib, pkgs, ... }:

{

  users.groups = {

    "plugdev" = {
      gid = 10000;
    };

  };

}