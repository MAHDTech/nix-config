{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.pcscd = {
    # NOTE: PCSCD conflicts with gpg-agent
    enable = false;
  };
}
