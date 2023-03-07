{
  networking = {
    firewall = {
      enable = false;

      trustedInterfaces = ["docker0"];

      allowedTCPPorts = [
        17500
        5000
        8080
        8000
        8443
      ];

      allowedUDPPorts = [
        17500
      ];
    };
  };
}
