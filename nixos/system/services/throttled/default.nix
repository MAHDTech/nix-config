{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  # Enable fix for Intel CPU throttling.
  services.throttled = {enable = true;};
}
