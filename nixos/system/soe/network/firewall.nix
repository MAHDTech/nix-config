{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    iptables
  ];

  networking = {

    firewall = {
      enable = true;

      backend = "nftables";

      # Allow ICMP globally
      allowPing = true;

      trustedInterfaces = [
        "docker0"
      ];

      # Disable strict reverse path filtering.
      # This is needed for Docker containers to communicate with the host.
      checkReversePath = "loose";

      # Incoming -> Host
      extraInputRules = ''
        # KinD
        ip saddr 172.18.0.0/16 accept comment "Allow Kind Cluster to Host"
      '';

      # Forwarding -> Internet
      extraForwardRules = ''
        # Docker
        ip saddr 172.17.0.0/16 accept comment "Allow Docker to Internet"
        ip daddr 172.17.0.0/16 accept comment "Allow Internet to Docker"

        # KinD
        ip saddr 172.18.0.0/16 accept comment "Allow Kind to Internet"
        ip daddr 172.18.0.0/16 accept comment "Allow Internet to Kind"
      '';

      allowedUDPPorts = [
        ##################################################
        # iVentoy
        ##################################################

        # DHCP snooper (client requests)
        # sudo nft add rule inet nixos-fw input-allow udp dport 67 accept
        67

        # DHCP snooper (server responses)
        # sudo nft add rule inet nixos-fw input-allow udp dport 68 accept
        68

        # TFTP for PXE boot file transfer
        # sudo nft add rule inet nixos-fw input-allow udp dport 69 accept
        69

        ##################################################
      ];

      allowedTCPPorts = [
        ##################################################
        # iVentoy
        ##################################################

        # NBD for ISO streaming
        # sudo nft add rule inet nixos-fw input-allow tcp dport 10809 accept
        10809

        # HTTP for boot files/menu
        # sudo nft add rule inet nixos-fw input-allow tcp dport 16000 accept
        16000

        # Web UI
        # sudo nft add rule inet nixos-fw input-allow tcp dport 26000 accept
        26000

        ##################################################
      ];
    };

    nat = {
      enable = true;
      internalIPs = [
        "172.17.0.0/16" # Docker
        "172.18.0.0/16" # KinD
      ];
      #externalInterface = "br0"; # The external interface with a host network IP.
    };

    nftables = {
      enable = true;
    };
  };
}
