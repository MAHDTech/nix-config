{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: systemd.nix
# Description: Systemd User configuration
##################################################

{

  systemd.user.startServices = true ;

  services = {

  };

}
