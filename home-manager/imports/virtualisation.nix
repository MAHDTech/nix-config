{ config, lib, pkgs, ... }:

##################################################
# Name: virtualisation.nix
# Description: nix config for containers and VMs
##################################################

{

  home.packages = with pkgs; [

    docker
    docker-ls
    docker-gc
    docker-client
    docker-buildx

  ];

  virtualisation = {

    oci-containers = {

      backend = "docker" ;

    };

    # https://search.nixos.org/options?from=0&size=50&sort=alpha_asc&query=virtualisation.docker
    docker = {

      enable = true ;

      package = pkgs.docker ;

      enableOnBoot = true ;

      logDriver = "journald" ;

      storageDriver = "zfs" ; 

      autoPrune.enable = true ;
      autoPrune.dates = "weekly" ;
      autoPrune.flags = [
        "--all"
      ];

    };

    podman = {

      enable = false ;

      # Create a 'docker' alias for podman
      dockerCompat = true ;

    };

  };

}

