{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [
    cosmic-edit
    cosmic-comp
    cosmic-panel
    cosmic-icons
    cosmic-applets
    cosmic-settings
  ];
}
