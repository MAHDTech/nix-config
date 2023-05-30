{globalStateVersion, ...}: let
  stateVersion = globalStateVersion;
in {
  programs.home-manager = {enable = true;};

  home = {
    enableNixpkgsReleaseCheck = true;

    inherit stateVersion;
  };

  targets.genericLinux.enable = true;
}
