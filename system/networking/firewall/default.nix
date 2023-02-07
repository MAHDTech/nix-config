{ config, lib, nixpkgs, pkgs, ... }:

{

  networking = {

    firewall = {

      enable = false;

      trustedInterfaces = [
        "docker0"
      ];

      allowedTCPPorts = [
        17500
      ];

      allowedUDPPorts = [
        17500
      ];

    };

  };

}