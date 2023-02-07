{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

    ./firewall
    ./networkmanager
    ./wireless


  ];

  environment.systemPackages = with pkgs; [

  ];

  networking = {

    enableIPv6 = true;

    useDHCP = false;

    resolvconf = {

      enable = true;

      useLocalResolver = false;
      dnsExtensionMechanism = true;
      dnsSingleRequest = true;

    };

  };

}