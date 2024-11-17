{
  services.cloudflared = {
    enable = false;

    user = "cloudflared";
    group = "cloudflared";

    tunnels = {
      "kasmweb" = {
        default = "http_status:404";

        # https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-useful-terms/#credentials-file
        # TLDR;
        #  cloudflared tunnel login <token-from-the-dashboard>
        #  cloudflared tunnel create <name>
        #credentialsFile = "${config.sops.secrets.cloudflared.credentialsFile}";
        credentialsFile = "/home/cloudflared/.secrets/cloudflared.json";

        # https://developers.cloudflare.com/cloudflare-one/tutorials/warp-to-tunnel/
        warp-routing = {
          enabled = false;
        };

        ingress = {
          "kasmweb.saltlabs.cloud" = "https://kasmweb.saltlabs.cloud";
        };

        originRequest = {
          tlsTimeout = "10s";
          tcpKeepAlive = "30s";
          proxyType = "";
          proxyPort = 0;
          proxyAddress = "127.0.0.1";
          originServerName = "kasmweb.saltlabs.cloud";
          noTLSVerify = false;
          noHappyEyeballs = false;
          keepAliveTimeout = "1m30s";
          keepAliveConnections = 25;
          httpHostHeader = "kasmweb.saltlabs.cloud";
          disableChunkedEncoding = false;
          connectTimeout = "30s";
        };
      };
    };
  };
}
