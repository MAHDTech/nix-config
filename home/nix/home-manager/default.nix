{
  globalStateVersion,
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  stateVersion = globalStateVersion;
in {
  programs.home-manager = {enable = true;};

  home = {
    enableNixpkgsReleaseCheck = true;

    inherit stateVersion;
  };
}
