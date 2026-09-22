{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rustfs-managed;
  inherit (lib) mkOption types;
  fileOption =
    description:
    mkOption {
      type = types.str;
      inherit description;
    };
  python = pkgs.python3.withPackages (ps: [
    ps.boto3
    ps.requests
  ]);
  manifest = pkgs.writeText "rustfs-buckets.json" (
    builtins.toJSON {
      endpoint = "http://127.0.0.1:${toString cfg.apiPort}";
      inherit (cfg) region buckets;
      writers = lib.mapAttrs (_: writer: { inherit (writer) buckets; }) cfg.writers;
    }
  );
  rootCredentials = [
    "root-access:${cfg.rootAccessKeyFile}"
    "root-secret:${cfg.rootSecretKeyFile}"
  ];
  validName = name: builtins.match "[a-z0-9][a-z0-9-]*[a-z0-9]" name != null;
in
{
  options.services.rustfs-managed = {
    enable = lib.mkEnableOption "managed RustFS cache buckets";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/rustfs";
    };
    apiPort = mkOption {
      type = types.port;
      default = 9000;
    };
    consolePort = mkOption {
      type = types.port;
      default = 9001;
    };
    region = mkOption {
      type = types.str;
      default = "us-east-1";
    };
    rootAccessKeyFile = fileOption "Runtime file containing the administrator access key.";
    rootSecretKeyFile = fileOption "Runtime file containing the administrator secret key.";
    buckets = mkOption {
      default = { };
      description = "Managed buckets. Removing an entry never deletes its objects or bucket.";
      type = types.attrsOf (
        types.submodule {
          options = {
            publicRead = mkOption {
              type = types.bool;
              default = false;
              description = "Allow anonymous GetObject, but not bucket listing or writes.";
            };
            retentionDays = mkOption {
              type = types.ints.positive;
              default = 30;
              description = "Expire objects by age, not last access; lifecycle enforcement is asynchronous.";
            };
            abortMultipartDays = mkOption {
              type = types.ints.positive;
              default = 1;
            };
          };
        }
      );
    };
    writers = mkOption {
      default = { };
      description = "Managed IAM writers with read, list, upload and delete access to selected buckets. Removed writers are disabled, not deleted.";
      type = types.attrsOf (
        types.submodule {
          options = {
            accessKeyFile = fileOption "Runtime writer access-key file.";
            secretKeyFile = fileOption "Runtime writer secret-key file.";
            buckets = mkOption { type = types.listOf types.str; };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.apiPort != cfg.consolePort;
        message = "RustFS API and console ports must differ.";
      }
      {
        assertion = lib.all (
          name: validName name && builtins.stringLength name >= 3 && builtins.stringLength name <= 63
        ) (builtins.attrNames cfg.buckets);
        message = "RustFS managed bucket names must be 3–63 lowercase alphanumeric/hyphen characters, beginning and ending with an alphanumeric.";
      }
      {
        assertion = lib.all (name: validName name && name != "root") (builtins.attrNames cfg.writers);
        message = "RustFS writer names must be lowercase alphanumeric/hyphen names other than root.";
      }
      {
        assertion = lib.all (
          writer: writer.buckets != [ ] && lib.all (name: builtins.hasAttr name cfg.buckets) writer.buckets
        ) (builtins.attrValues cfg.writers);
        message = "Every RustFS writer must reference at least one declared bucket.";
      }
      {
        assertion = lib.all (path: lib.hasPrefix "/" path && !(lib.hasPrefix "/nix/store/" path)) (
          [
            cfg.rootAccessKeyFile
            cfg.rootSecretKeyFile
          ]
          ++ lib.concatMap (writer: [
            writer.accessKeyFile
            writer.secretKeyFile
          ]) (builtins.attrValues cfg.writers)
        );
        message = "RustFS credentials must be runtime files outside the Nix store.";
      }
    ];
    services.rustfs = {
      enable = true;
      # Credentials are supplied by systemd, not a secret-bearing environment file.
      environmentFile = "/dev/null";
      settings = {
        RUSTFS_VOLUMES = cfg.dataDir;
        RUSTFS_ADDRESS = "127.0.0.1:${toString cfg.apiPort}";
        RUSTFS_CONSOLE_ENABLE = "true";
        RUSTFS_CONSOLE_ADDRESS = "127.0.0.1:${toString cfg.consolePort}";
        RUSTFS_REGION = cfg.region;
      };
    };
    systemd = {
      services = {
        rustfs = {
          # The upstream preStart only recognises literal environment credentials.
          # RustFS itself supports the file variants; check the systemd copies instead.
          preStart = lib.mkForce ''
            test -s "$RUSTFS_ACCESS_KEY_FILE"
            test -s "$RUSTFS_SECRET_KEY_FILE"
          '';
          wants = [ "rustfs-provision.service" ];
          serviceConfig = {
            LoadCredential = rootCredentials;
            Environment = [
              "RUSTFS_ACCESS_KEY_FILE=%d/root-access"
              "RUSTFS_SECRET_KEY_FILE=%d/root-secret"
            ];
          };
        };
        rustfs-provision = {
          description = "Reconcile RustFS cache buckets and scoped writer identities";
          wantedBy = [ "multi-user.target" ];
          requires = [ "rustfs.service" ];
          after = [ "rustfs.service" ];
          restartTriggers = [
            manifest
            ./reconcile.py
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${python}/bin/python3 ${./reconcile.py} ${manifest}";
            StateDirectory = "rustfs-provision";
            StateDirectoryMode = "0700";
            UMask = "0077";
            LoadCredential =
              rootCredentials
              ++ lib.concatLists (
                lib.mapAttrsToList (name: writer: [
                  "${name}-access:${writer.accessKeyFile}"
                  "${name}-secret:${writer.secretKeyFile}"
                ]) cfg.writers
              );
            TimeoutStartSec = "10min";
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
          };
        };
      };
      timers.rustfs-provision = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitInactiveSec = "15min";
        };
      };
    };
  };
}
