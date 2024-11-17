{
  pkgs,
  lib,
  config,
  ...
}: {
  # The kasmweb username.
  options.kasmwebconfig = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "kasm";
    };

    # The kasmweb redis password.
    redisPassword = lib.mkOption {
      type = lib.types.str;
      default = "kasm";
    };

    postgres = {
      # The kasmweb postgres user.
      user = lib.mkOption {
        type = lib.types.str;
        default = "kasm";
      };

      # The kasmweb postgres password.
      password = lib.mkOption {
        type = lib.types.str;
        default = "kasm";
      };
    };
  };

  config = {
    environment.systemPackages = with pkgs; [];

    services.kasmweb = {
      enable = true;

      listenPort = 443;
      listenAddress = "0.0.0.0";

      networkSubnet = "172.20.0.0/16";

      sslCertificate = "/home/${config.kasmwebconfig.user}/certs/kasmweb.pem";
      sslCertificateKey = "/home/${config.kasmwebconfig.user}/certs/kasmweb.key";

      datastorePath = "/var/lib/kasmweb";

      redisPassword = "${config.kasmwebconfig.redisPassword}";

      postgres = {
        user = "${config.kasmwebconfig.postgres.user}";
        password = "${config.kasmwebconfig.postgres.password}";
      };

      defaultUserPassword = "kasmweb";
      defaultRegistrationToken = "kasmweb";
      defaultManagerToken = "kasmweb";
      defaultGuacToken = "kasmweb";
      defaultAdminPassword = "kasmweb";
    };
  };
}
