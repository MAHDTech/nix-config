{
  services.tailscale = {
    enable = true;

    useRoutingFeatures = "client";

    openFirewall = true;

    extraUpFlags = [
      "--accept-routes"
    ];

    extraDaemonFlags = [
      "--no-logs-no-support"
    ];
  };
}
