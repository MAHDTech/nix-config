{pkgs, ...}: {
  imports = [
    ./firewall

    ./networkmanager

    #./wireless         # Configured per-host.
  ];

  environment.systemPackages = with pkgs; [];

  networking = {
    useNetworkd = true;
    dhcpcd.enable = false;

    enableIPv6 = true;

    useDHCP = false;

    useHostResolvConf = false;
  };
}
