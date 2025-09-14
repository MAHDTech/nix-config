{

  # NOTE: Steam is installed via flatpak.

  # Allow ports required for Steam Link.
  networking = {
    firewall = {
      allowedUDPPorts = [
        27031
        27036
      ];
      allowedTCPPorts = [
        27036
        27037
      ];
    };
  };

}
