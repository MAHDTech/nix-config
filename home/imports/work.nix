{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: vmware.nix
# Description: VMware sofrtware and settings.
##################################################

{

  home.packages = with pkgs; [

    citrix_workspace
    slack
    teams
    vmware-horizon-client

  ];

}
