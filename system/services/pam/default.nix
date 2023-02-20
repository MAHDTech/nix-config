{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  security.pam.services = {
    login.u2fAuth = true;

    sudo.u2fAuth = true;
  };
}
