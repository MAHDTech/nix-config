{ inputs, config, lib, pkgs, ... }:

{

  imports = [

    ./firewall
    ./networkmanager
    ./wireless


  ];

  environment.systemPackages = with pkgs; [

  ];

  networking = {

    useNetworkd = true;

    enableIPv6 = true;

    useDHCP = false;

    useHostResolvConf = false;

    /*
    resolvconf = {

      enable = true;

      useLocalResolver = false;
      dnsExtensionMechanism = true;
      dnsSingleRequest = true;

      extraConfig = "";

    };
    */

  };

}
