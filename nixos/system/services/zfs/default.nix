{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.zfs = {
    autoScrub = {
      enable = true;

      interval = "weekly";

      # Configured per-host.
      #pools = [];
    };

    trim = {
      enable = true;

      interval = "weekly";
    };
  };
}
