{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.dhcpd4 = {enable = false;};

  services.dhcpd6 = {enable = false;};
}
