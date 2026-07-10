{
  lib,
  pkgs,
  syncthingConfig ? null,
  ...
}:
{

  # Ensure the Syncthing directories have standard .stignore files configured
  home.file = lib.mkIf (syncthingConfig != null) (
    lib.listToAttrs (
      lib.mapAttrsToList (name: folder: {
        name = "${name}-stignore";
        value = {
          enable = true;
          force = true;
          executable = false;
          target = "${folder.path}/.stignore";
          text = ''
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
      }) (syncthingConfig.syncFolders or { })
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
          watch = false;
          order = "smallestFirst";
          rescanIntervalS = folderConfig.rescanIntervalS or 14400; # Default to 4 hours
          versioning =
            folderConfig.versioning or {
              type = "staggered";
              params = {
                cleanInterval = "86400"; # Clean daily
                maxAge = "2592000"; # Keep versions for up to 30 days
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
          maxFolderConcurrency = 2;
          weakHashThresholdPct = 101; # Disable weak hashing to save CPU

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
