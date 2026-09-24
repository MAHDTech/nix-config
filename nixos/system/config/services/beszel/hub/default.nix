{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.beszel.hub;
  managed = cfg.systems != null;
  systems = if managed then cfg.systems else { };
  manifest = pkgs.writeText "beszel-inventory.json" (
    builtins.toJSON {
      privateKey = cfg.privateKeyFile != null;
      inherit managed;
      systems = lib.mapAttrs (name: system: {
        inherit (system) host port users;
        tokenCredential = "token-${name}";
      }) systems;
    }
  );
  runtimePath = path: lib.hasPrefix "/" path && !(lib.hasPrefix "/nix/store/" path);
in
{
  imports = [
    ./opnix.nix
    ./frontend.nix
  ];
  options.services.beszel.hub = {
    privateKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime OpenSSH private-key file, delivered through systemd credentials.";
    };
    systems = lib.mkOption {
      default = null;
      description = "Authoritative system inventory. Null leaves inventory unmanaged. Removing a member deletes its Beszel record on restart.";
      type = lib.types.nullOr (
        lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }: {
              options = {
                host = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                };
                port = lib.mkOption {
                  type = lib.types.port;
                  default = 45876;
                };
                users = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Existing user emails; empty uses the bootstrap USER_EMAIL at runtime.";
                };
                tokenFile = lib.mkOption { type = lib.types.str; };
              };
            }
          )
        )
      );
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.privateKeyFile == null || runtimePath cfg.privateKeyFile;
        message = "Beszel private keys must be runtime files outside the Nix store.";
      }
      {
        assertion = lib.all (system: runtimePath system.tokenFile) (builtins.attrValues systems);
        message = "Beszel tokens must be runtime files outside the Nix store.";
      }
      {
        assertion = !managed || systems != { };
        message = "Beszel's empty inventory does not remove systems; use null for unmanaged inventory.";
      }
      {
        assertion = lib.all (name: builtins.match "[a-zA-Z0-9][a-zA-Z0-9_-]*" name != null) (
          builtins.attrNames systems
        );
        message = "Beszel inventory names must be alphanumeric with hyphens or underscores.";
      }
    ];
    systemd.services.beszel-hub = {
      restartTriggers = [ manifest ];
      serviceConfig = {
        LoadCredential =
          lib.optional (cfg.privateKeyFile != null) "hub-private-key:${cfg.privateKeyFile}"
          ++ lib.mapAttrsToList (name: system: "token-${name}:${system.tokenFile}") systems;
        ExecStartPre = lib.mkBefore [
          "${pkgs.python3}/bin/python3 ${./prepare.py} ${manifest} ${cfg.dataDir}/beszel_data ${pkgs.openssh}/bin/ssh-keygen"
        ];
      };
    };
  };
}
