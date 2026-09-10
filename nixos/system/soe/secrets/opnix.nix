{ config, lib, ... }: {
  services.onepassword-secrets = {
    enable = lib.mkDefault (
      config.services.onepassword-secrets.secrets != { }
      || config.services.onepassword-secrets.configFiles != [ ]
    );
    tokenFile = "/etc/opnix-token";
    secrets = { };
  };
}
