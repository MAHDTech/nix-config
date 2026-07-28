{
  lib,
  pkgs,
  syncthingConfig ? null,
  ...
}:
let

  # .stignore profile: default
  # Full file sync with common build artifacts and ephemeral state excluded.
  # Use for general-purpose directories (documents, configs, media).
  stignoreDefault = ''
    // Subdirectories managed by their own Syncthing folder
    // Projects/ uses the git-only profile and must not be double-synced
    Projects

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

  # .stignore profile: git-only
  # Only sync immutable git internals: objects, refs, packed-refs, info, description.
  # Ignores worktree files, index, HEAD, config, hooks, logs, and all operation state.
  # Each machine does its own `git checkout` after Syncthing delivers the .git/ directory.
  #
  # This eliminates churn from:
  #   - AI agent branch checkouts and worktree operations
  #   - Dirty/uncommitted file changes
  #   - Machine-specific git config and hooks
  #   - The dangerous .git/index (staging area) which causes corruption when synced
  stignoreGitOnly = ''
    // ============================================================
    // Git-Only Sync Profile
    // ============================================================
    // ALLOWED (not listed = synced):
    //   **/.git/objects/    — immutable content-addressed blobs/trees/commits
    //   **/.git/refs/       — branch and tag pointers
    //   **/.git/packed-refs — packed reference file
    //   **/.git/info/       — exclude patterns, attributes
    //   **/.git/description — repository description
    // ============================================================

    // --- Dangerous git state (MUST ignore at any depth) ---

    // The index/staging area — syncing this against a different worktree corrupts repos
    **/.git/index

    // Current branch pointer — machine-specific
    **/.git/HEAD

    // Per-repo config — contains machine-specific remotes, paths, settings
    **/.git/config

    // Executable hooks — may have machine-specific paths/tools
    **/.git/hooks/**

    // Reflogs — machine-specific operation history
    **/.git/logs/**

    // Worktree metadata — contains machine-specific absolute paths
    **/.git/worktrees/**

    // --- In-progress operation state ---
    **/.git/COMMIT_EDITMSG
    **/.git/MERGE_HEAD
    **/.git/MERGE_MODE
    **/.git/MERGE_MSG
    **/.git/REBASE_HEAD
    **/.git/rebase-merge/**
    **/.git/rebase-apply/**
    **/.git/CHERRY_PICK_HEAD
    **/.git/BISECT_LOG
    **/.git/BISECT_NAMES
    **/.git/BISECT_TERMS
    **/.git/SQUASH_MSG
    **/.git/REVERT_HEAD
    **/.git/AUTO_MERGE
    **/.git/FETCH_HEAD
    **/.git/ORIG_HEAD
    **/.git/shallow

    // Lock files at any depth inside .git/
    **/.git/*.lock
    **/.git/**/*.lock

    // --- Worktree files (everything outside .git/) ---
    // Syncthing evaluates patterns top-to-bottom, first match wins.
    // First: preserve .git/ directories at any depth
    // Then: ignore everything else (non-.git files/dirs)
    !**/.git
    !**/.git/**
    **

    // --- Syncthing conflicts ---
    *.sync-conflict-*
  '';

  # Select the .stignore content based on the folder's profile setting
  stignoreForProfile = profile: if profile == "git-only" then stignoreGitOnly else stignoreDefault;

in
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
          text = stignoreForProfile (folder.stignoreProfile or "default");
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
