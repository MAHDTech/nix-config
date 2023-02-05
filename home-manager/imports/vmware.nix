{ config, lib, pkgs, ... }:

##################################################
# Name: vmware.nix
# Description: VMware sofrtware and settings.
##################################################

{

  nixpkgs.config = {

    allowUnfree = true ;

  };

  home.packages = with pkgs; [

    # VMware

    vmware-workstation
    vmware-horizon-client
    ovftool

  ];

}
