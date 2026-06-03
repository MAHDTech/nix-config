_: {
  services.onepassword-secrets = {
    enable = true;
    tokenFile = "/etc/opnix/token";
    secrets = {
      "incusAcme" = {
        reference = "op://fleet/Incus/acme-env";
        path = "/run/secrets/incus-acme.env";
        owner = "root";
        group = "root";
        mode = "0400";
        services = [
          "incus-preseed.service"
          "incus.service"
        ];
      };
    };
  };
}
