{
  services.tailscale = {
    enable = true;

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
