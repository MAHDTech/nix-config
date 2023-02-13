{ globalStateVersion, config, lib, pkgs, ... }:

##################################################
# Name: home-manager.nix
# Description: Home Manager configuration.
##################################################

let

  stateVersion = globalStateVersion;

in {

  programs.home-manager = {

    enable = true ;

  };

  home = {

    enableNixpkgsReleaseCheck = true ;

    inherit stateVersion;

  };

  # HACK: Untill I can fix the flake config.
  home.sessionVariables = {

    NIXPKGS_ALLOW_UNFREE = 1;

  };

}
