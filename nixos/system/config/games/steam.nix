{

  programs = {
    steam = {
      enable = true;
      remotePlay = {
        openFirewall = true;
      };
      protontricks = {
        enable = true;
      };
      gamescopeSession = {
        enable = true;
      };
      extest = {
        enable = true;
      };
      dedicatedServer = {
        openFirewall = true;
      };
    };
  };

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
