{
  syncthingConfig = {
    deviceName = "JONS";
    deviceId = "OZ2YWNW-ARZCGC2-XPHTLXN-SNO6VGZ-A4V5JWK-KXS5ISI-3NDFJQB-HSM6VQC";
    otherDevices = [ ];
    syncFolders = {
      # General sync — documents, configs, media, etc.
      # Ignores Projects/ (handled by the git-only folder below)
      "Sync" = {
        enable = true;
        id = "syncthing-shared";
        path = "/home/mahdtech/Sync";
        type = "sendreceive";
        stignoreProfile = "default";

        devices = [ ];
      };

      # Git-only sync — only immutable .git/ internals (objects, refs, packed-refs)
      # No worktree files, no index, no HEAD, no hooks, no config
      # Each machine does its own `git checkout` after Syncthing delivers .git/
      "Projects" = {
        enable = true;
        id = "syncthing-projects";
        path = "/home/mahdtech/Sync/Projects";
        type = "sendreceive";
        stignoreProfile = "git-only";

        # Disable versioning — git IS the version control system
        versioning = null;

        devices = [ ];
      };
    };
  };
}
