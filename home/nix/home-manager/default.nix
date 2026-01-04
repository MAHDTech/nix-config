{
  globalStateVersion,
  globalUsername,
  ...
}:
let
  stateVersion = globalStateVersion;
  username = globalUsername;
in
{
  programs.home-manager = {
    enable = true;
  };

  home = {
    enableNixpkgsReleaseCheck = true;

    inherit stateVersion;
    inherit username;

    homeDirectory = "/home/${username}";
  };

  # NixOS or Generic Linux
  targets.genericLinux.enable = false;
}
