{ inputs, config, lib, pkgs, ... }:

##################################################
# Name: ansible.nix
# Description: Ansible configuration
##################################################

{

  home.packages = with pkgs; [

    ansible
    ansible-lint
    crudini

  ];

}
