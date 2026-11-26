{
  imports = [
    ./firewall.nix
  ];

  networking = {
    useNetworkd = true;

    dhcpcd.enable = false;

    # Keep NetworkManager disabled even when desktop modules (e.g. COSMIC) set
    # mkDefault true, so it does not compete with systemd-networkd / iwd.
    networkmanager.enable = false;

    enableIPv6 = true;

    useDHCP = false;

    useHostResolvConf = false;
  };
}
