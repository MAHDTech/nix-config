{
  networking = {
    firewall = {
      enable = false;

      trustedInterfaces = ["docker0"];

      allowedTCPPorts = [
        1313
        17500
        443
        5000
        80
        8000
        8080
        8443
      ];

      allowedUDPPorts = [
        17500
      ];
    };
  };
}
