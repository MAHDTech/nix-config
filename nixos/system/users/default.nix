{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./root ./mahdtech];

  users.mutableUsers = false;
}
