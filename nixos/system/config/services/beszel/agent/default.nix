{ config, lib, ... }:
let
  cfg = config.services.beszel.agent;
  op = cfg.opnix;
  secret = reference: path: {
    inherit reference path;
    owner = "root";
    group = "root";
    mode = "0400";
    services = [ "beszel-agent.service" ];
  };
in
{
  imports = [ ../../../../soe/secrets/opnix.nix ];
  options.services.beszel.agent.opnix = {
    enable = lib.mkEnableOption "Opnix credentials for the Beszel agent";
    publicKeyReference = lib.mkOption {
      type = lib.types.str;
      description = "1Password reference to the hub's OpenSSH public key.";
    };
    tokenReference = lib.mkOption {
      type = lib.types.str;
      description = "1Password reference to this agent's registration token.";
    };
  };
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.beszel.agent = {
          openFirewall = lib.mkDefault false;
          smartmon.enable = lib.mkDefault false;
          environment = {
            DISABLE_SSH = lib.mkDefault "true";
            SKIP_SYSTEMD = lib.mkDefault false;
          };
        };
      }
      (lib.mkIf op.enable {
        services.onepassword-secrets.secrets = {
          beszelAgentKey = secret op.publicKeyReference "/run/secrets/beszel-agent-key";
          beszelAgentToken = secret op.tokenReference "/run/secrets/beszel-agent-token";
        };
        services.beszel.agent.environment = {
          KEY_FILE = lib.mkDefault "%d/hub-public-key";
          TOKEN_FILE = lib.mkDefault "%d/agent-token";
        };
        systemd.services.beszel-agent = {
          requires = [ "opnix-secrets.service" ];
          after = [ "opnix-secrets.service" ];
          serviceConfig.LoadCredential = [
            "hub-public-key:/run/secrets/beszel-agent-key"
            "agent-token:/run/secrets/beszel-agent-token"
          ];
        };
      })
    ]
  );
}
