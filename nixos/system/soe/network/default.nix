{pkgs, ...}: {
  imports = [
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
