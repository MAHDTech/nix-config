{ config, lib, pkgs, ... }:

##################################################
# Name: ssh.nix
# Description: Nix home-manager config for SSH
# Notes:
#
#   * This configuration now uses OpenSSH Agent
#     instead of the GPG Agent for SSH.
#
#   * The SSH keys from the smart cards are loaded
#     into the agent during loading of .bashrc
#
#   * If you have a YubiKey 5, use the newer method
#     described below that uses resident sk keys.
#     https://www.yubico.com/blog/github-now-supports-ssh-security-keys/
#
##################################################

{

  programs.ssh = {

    enable = true ;

    compression = true ;

    controlMaster = "no" ;
    controlPath = "~/.ssh/control-master/%r@%h:%p" ;
    controlPersist = "600" ;

    hashKnownHosts = false ;

    forwardAgent = true ;

    serverAliveCountMax = 3 ;
    serverAliveInterval = 60 ;

    # Include any extra files with SSH config.
    includes = [

    ];

    # These options override any Host settings globally.
    extraOptionOverrides = {

    };

    matchBlocks = {

      "TT-1" = {
        host = "tt-1" ;
        hostname = "tt-1.mahdtech.com" ;
        user = "root" ;
        addressFamily = "inet" ;
        forwardAgent = true ;
        forwardX11 = false ;
        forwardX11Trusted = false ;
        identitiesOnly = false ;
      };

      "TT-2" = {
        host = "tt-2" ;
        hostname = "tt-2.mahdtech.com" ;
        user = "root" ;
        addressFamily = "inet" ;
        forwardAgent = true ;
        forwardX11 = false ;
        forwardX11Trusted = false ;
        identitiesOnly = false ;
      };

    };

  };

}
