{
  lib,
  pkgs,
  syncthingConfig ? null,
  ...
}:
{

  # Ensure the Syncthing directories exist and have standard .stignore files configured
  home.file = lib.mkIf (syncthingConfig != null) (
    lib.listToAttrs (
      lib.concatLists (
        lib.mapAttrsToList (name: folder: [
          {
            name = "${name}-keep-file";
            value = {
              enable = true;
              force = true;
              executable = false;
              target = "${folder.path}/.keep";
              text = "This folder named '${name}' is managed by Syncthing.";
            };
          }
          {
            name = "${name}-stignore";
            value = {
              enable = true;
              force = true;
              executable = false;
              target = "${folder.path}/.stignore";
              text = ''
                // Ignore all Git history and metadata
                // (?d).git/

                // Ephemeral Git state/locks
                // Sync working directory and git history, but ignore locks
                (?d).git/*.lock
                (?d).git/index.lock

                // Nix & Flake Ephemerals
                result
                result-*
                .direnv/
                .devenv/
                .pre-commit/

                // Common Build/Language Artifacts
                node_modules/
                target/
                .venv/
                dist/
                build/
                .cache/

                // OS/IDE files
                .DS_Store
                .idea/
                .vscode/

                // Syncthing conflicts
                (?d)*.sync-conflict-*
              '';
            };
          }
        ]) (syncthingConfig.syncFolders or { })
      )
    )
  );

  services = lib.mkIf (syncthingConfig != null) {
    syncthing = {
      enable = true;

      package = pkgs.syncthing;

      guiAddress = syncthingConfig.guiAddress or "127.0.0.1:8384";

      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = lib.listToAttrs (
          map (device: {
            inherit (device) name;
            value = {
              inherit (device) id name autoAcceptFolders;
            };
          }) (syncthingConfig.otherDevices or [ ])
        );

        folders = lib.mapAttrs (folderName: folderConfig: {
          inherit (folderConfig)
            id
            path
            type
            enable
            devices
            ;
          label = folderName;
          copyOwnershipFromParent = false;
          rescanIntervalS = folderConfig.rescanIntervalS or 86400;
          versioning =
            folderConfig.versioning or {
              type = "staggered";
              params = {
                cleanInterval = "3600"; # Clean hourly
                maxAge = "31536000"; # Keep versions for up to 365 days
              };
            };
        }) (syncthingConfig.syncFolders or { });

        options = {
          # Network configuration
          localAnnounceEnabled = true;
          localAnnouncePort = 21027;
          relaysEnabled = true;

          # Bandwidth and performance
          limitBandwidthInLan = false;
          maxFolderConcurrency = 0;

          # Disable usage reporting.
          urAccepted = -1;
        };

        gui = {
          theme = "default";
          insecureAdminAccess = false;
          insecureSkipHostCheck = false;
          insecureAllowFrameLoading = false;
        };
      };

      extraOptions = [ ];

      tray = {
        enable = false;
      };
    };
  };
}
