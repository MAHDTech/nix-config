{pkgs, ...}: {
  imports = [
    ./firewall

    ./networkmanager

    ./wireless
  ];

  environment.systemPackages = with pkgs; [];

  # Currently using;
  #   - systemd-network for LAN
  #   - NetworkManager for WLAN

  networking = {
    useNetworkd = true;

    dhcpcd.enable = false;

    enableIPv6 = true;

    useDHCP = false;

    useHostResolvConf = false;
  };
}
