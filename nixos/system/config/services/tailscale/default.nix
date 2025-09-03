{
  services.tailscale = {
    enable = false; # TODO: Broken in September 2025.

    useRoutingFeatures = "client";

    openFirewall = true;

    extraUpFlags = [
      "--accept-dns=true"
      "--accept-routes=true"
    ];

    extraDaemonFlags = [
      "--no-logs-no-support"
    ];
  };
}
