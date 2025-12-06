{
  networking = {
    firewall = {
      enable = true;
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
    nftables = {
      enable = true;
    };
  };
}
