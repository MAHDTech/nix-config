{ config, lib, ... }:
let
  cfg = config.services.beszel.hub;
  op = cfg.opnix;
  secret = reference: path: {
    inherit reference path;
    owner = "root";
    group = "root";
    mode = "0400";
    services = [ "beszel-hub.service" ];
  };
in
{
  imports = [ ../../../../soe/secrets/opnix.nix ];
  options.services.beszel.hub.opnix = {
    enable = lib.mkEnableOption "Opnix credentials for the Beszel hub";
    privateKeyReference = lib.mkOption { type = lib.types.str; };
    bootstrapReference = lib.mkOption {
      type = lib.types.str;
      description = "1Password field containing USER_EMAIL and USER_PASSWORD in systemd EnvironmentFile syntax.";
    };
    tokenReferences = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Inventory member names mapped to their 1Password token references.";
    };
  };
  config = lib.mkIf (cfg.enable && op.enable) {
    services.beszel.hub = {
      privateKeyFile = lib.mkDefault "/run/secrets/beszel-hub-private-key";
      environmentFile = lib.mkDefault "/run/secrets/beszel-hub-bootstrap";
      systems = lib.mkIf (op.tokenReferences != { }) (
        lib.mapAttrs (name: _: {
          tokenFile = lib.mkDefault "/run/secrets/beszel-hub-token-${name}";
        }) op.tokenReferences
      );
    };
    services.onepassword-secrets.secrets = {
      beszelHubKey = secret op.privateKeyReference "/run/secrets/beszel-hub-private-key";
      beszelHubBootstrap = secret op.bootstrapReference "/run/secrets/beszel-hub-bootstrap";
    }
    // lib.mapAttrs' (
      name: reference:
      # Opnix identifiers must be alphanumeric; hashing avoids hostname collisions.
      lib.nameValuePair "beszelHubToken${builtins.hashString "sha256" name}" (
        secret reference "/run/secrets/beszel-hub-token-${name}"
      )
    ) op.tokenReferences;
    systemd.services.beszel-hub = {
      requires = [ "opnix-secrets.service" ];
      after = [ "opnix-secrets.service" ];
    };
  };
}
