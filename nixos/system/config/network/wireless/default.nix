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
            # Regulatory country code — sets the WiFi regulatory domain.
            # Required for Snapdragon X Elite (ath12k/wcn7850) which times out
            # waiting for a country update if none is configured.
            Country = "AU";
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
