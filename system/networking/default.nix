{pkgs, ...}: {
  imports = [
    ./firewall

    ./networkmanager

    #./wireless         # Configured per-host.
  ];

  environment.systemPackages = with pkgs; [];

  networking = {
    useNetworkd = true;

    enableIPv6 = true;

    useDHCP = false;

    useHostResolvConf = false;
  };
}
