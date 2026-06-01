{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [ ];

  networking = {
    wireless = {
      enable = false; # Disable wpa_supplicant

      iwd = {
        # Whether to enable iwd
        enable = true;
        settings = {
          General = {
            EnableNetworkConfiguration = true;
            AddressRandomization = "network";
            AddressRandomizationRange = "nic";
          };
          Network = {
            EnableIPv6 = true;
            RoutePriorityOffset = 300;
          };
          Settings = {
            AutoConnect = true;
          };
        };
      };

    };
  };
}
