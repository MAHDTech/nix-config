{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.acpid = {enable = false;};
}
