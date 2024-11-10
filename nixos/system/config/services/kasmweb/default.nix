{
  pkgs,
  kasmUser,
  kasmRedisPassword,
  kasmPostgresUser,
  kasmPostgresPassword,
  ...
}: {
  environment.systemPackages = with pkgs; [];

  services.kasmweb = {
    enable = true;

    listenPort = 443;
    listenAddress = "0.0.0.0";

    networkSubnet = "172.20.0.0/16";

    sslCertificate = "/home/${kasmUser}/certs/kasmweb.pem";
    sslCertificateKey = "/home/${kasmUser}/certs/kasmweb.key";

    datastorePath = "/var/lib/kasmweb";

    redisPassword = kasmRedisPassword;

    postgres = {
      user = kasmPostgresUser;
      password = kasmPostgresPassword;
    };

    defaultUserPassword = "kasmweb";
    defaultRegistrationToken = "kasmweb";
    defaultManagerToken = "kasmweb";
    defaultGuacToken = "kasmweb";
    defaultAdminPassword = "kasmweb";
  };
}
