{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: vmware.nix
# Description: VMware sofrtware and settings.
##################################################

{

  home.packages = with pkgs; [

    slack
    teams

    citrix_workspace

    vmware-horizon-client

  ];

}
