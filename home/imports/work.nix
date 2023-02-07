{ config, lib, pkgs, ... }:

##################################################
# Name: vmware.nix
# Description: VMware sofrtware and settings.
##################################################

{

  home.packages = with pkgs; [

    vmware-horizon-client
    citrix_workspace

  ];

}
