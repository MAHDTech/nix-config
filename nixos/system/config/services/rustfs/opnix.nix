{ config, lib, ... }:
let
  cfg = config.services.rustfs-managed;
  op = cfg.opnix;
  secretPath = name: "/run/secrets/rustfs-${name}";
  secret = reference: path: services: {
    inherit reference path services;
    owner = "root";
    group = "root";
    mode = "0400";
  };
  secretName =
    name: suffix: "rustfs" + builtins.substring 0 16 (builtins.hashString "sha256" name) + suffix;
  writerSecrets = lib.concatMapAttrs (name: item: {
    ${secretName name "Access"} = secret "${item}/access_key" (secretPath "${name}-access") [
      "rustfs-provision.service"
    ];
    ${secretName name "Secret"} = secret "${item}/secret_key" (secretPath "${name}-secret") [
      "rustfs-provision.service"
    ];
  }) op.writerItems;
in
{
  imports = [
    ./default.nix
    ../../../soe/secrets/opnix.nix
  ];
  options.services.rustfs-managed.opnix = {
    enable = lib.mkEnableOption "Opnix delivery of RustFS credentials";
    adminItem = lib.mkOption {
      type = lib.types.str;
      description = "1Password item reference containing access_key and secret_key fields.";
    };
    writerItems = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Writer name to 1Password item reference.";
    };
  };
  config = lib.mkIf (cfg.enable && op.enable) {
    services.rustfs-managed = {
      rootAccessKeyFile = secretPath "root-access";
      rootSecretKeyFile = secretPath "root-secret";
      writers = lib.mapAttrs (name: _: {
        accessKeyFile = secretPath "${name}-access";
        secretKeyFile = secretPath "${name}-secret";
      }) op.writerItems;
    };
    services.onepassword-secrets.secrets = writerSecrets // {
      rustfsRootAccess = secret "${op.adminItem}/access_key" (secretPath "root-access") [
        "rustfs.service"
        "rustfs-provision.service"
      ];
      rustfsRootSecret = secret "${op.adminItem}/secret_key" (secretPath "root-secret") [
        "rustfs.service"
        "rustfs-provision.service"
      ];
    };
    systemd.services = {
      rustfs = {
        requires = [ "opnix-secrets.service" ];
        after = [ "opnix-secrets.service" ];
      };
      rustfs-provision = {
        requires = [ "opnix-secrets.service" ];
        after = [ "opnix-secrets.service" ];
      };
      opnix-secrets = {
        unitConfig.StartLimitIntervalSec = lib.mkForce 0;
        serviceConfig = {
          RestartPreventExitStatus = lib.mkForce [ ];
          RestartSec = lib.mkForce "1min";
        };
      };
    };
  };
}
