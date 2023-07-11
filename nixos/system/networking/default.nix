{pkgs, ...}: {
  imports = [
    ./firewall

    ./networkmanager

    ./wireless
  ];

  environment.systemPackages = with pkgs; [];

  # systemd-network for LAN
  # NetworkManager for WLAN

  networking = {
    useNetworkd = true;

    dhcpcd.enable = false;

    enableIPv6 = false;

    useDHCP = false;

    useHostResolvConf = false;
  };
}
