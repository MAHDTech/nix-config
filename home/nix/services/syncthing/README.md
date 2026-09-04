# Syncthing Configuration

This dynamic Syncthing module allows you to configure any number of machines to sync with each other by passing parameters.

## How It Works

Each machine gets configured with:

- Its own device name and ID
- A list of other devices it should connect to
- A list of folders to sync, each with its own `.stignore` profile

## .stignore Profiles

Each folder can specify a `stignoreProfile` to control what gets synced:

### `default` (default)

Full file sync with common build artifacts and ephemeral state excluded. Use for general-purpose directories (documents, configs, media).

Ignores:

- Lock files
- `.direnv/`, `.devenv/`, `node_modules/`, `target/`, `.venv/`, `dist/`, `build/`, `.cache/`
- IDE files
- Syncthing conflicts
- Subdirectories managed by their own Syncthing folder (e.g. `Projects/`)

### `git-only`

Only syncs immutable git internals — the object store and ref pointers.
Ignores the worktree, index, HEAD, config, hooks, logs, and all in-progress operation state.
Each machine does its own `git checkout` after Syncthing delivers the `.git/` directory.

**What syncs:**

- `.git/objects/` — immutable content-addressed blobs, trees, commits
- `.git/refs/` — branch and tag pointers
- `.git/packed-refs` — packed reference file
- `.git/info/` — exclude patterns, attributes
- `.git/description` — repository description

**What is ignored:**

- All worktree files (source code outside `.git/`)
- `.git/index` — staging area (syncing this corrupts repos)
- `.git/HEAD` — current branch pointer (machine-specific)
- `.git/config` — remotes, branch tracking (machine-specific)
- `.git/hooks/` — executable scripts (machine-specific paths)
- `.git/logs/` — reflogs (machine-specific)
- `.git/worktrees/` — worktree metadata (machine-specific paths)
- All operation state: `MERGE_*`, `REBASE_*`, `CHERRY_PICK_HEAD`, etc.
- Lock files, Syncthing conflicts

**Use case:** Sync git history across machines without churn from AI agent branch checkouts, dirty worktrees, or uncommitted changes. Each machine works independently and checks out branches locally.

## Usage Example

```nix
# For Machine A
../../home/nix/services/syncthing {
  deviceName = "MachineA";
  deviceId = "ABC123...";  # Get this with: syncthing -device-id
  otherDevices = [
    {
      name = "MachineB";
      id = "DEF456...";  # MachineB's device ID
      autoAcceptFolders = false;
    }
  ];
  syncFolders = {
    # General sync — full file replication
    "Sync" = {
      id = "syncthing-shared";
      path = "/home/user/Sync";
      type = "sendreceive";
      stignoreProfile = "default";
      devices = [ "MachineB" ];
    };

    # Git-only sync — only .git/ internals, no worktree
    "Projects" = {
      id = "syncthing-projects";
      path = "/home/user/Sync/Projects";
      type = "sendreceive";
      stignoreProfile = "git-only";

      # Disable versioning — git IS the version control system
      versioning = null;

      devices = [ "MachineB" ];
    };
  };
}
```

## Parameters

### Required Parameters

- `deviceName`: Name of the current machine
- `deviceId`: Syncthing device ID of the current machine

### Optional Parameters

- `otherDevices`: List of other devices to connect to
- `syncFolders`: Folders to sync with other devices. Each folder accepts:
  - `id`: Folder ID
  - `path`: Folder path
  - `type`: Sync type (default: "sendreceive")
  - `devices`: List of device names to sync with
  - `stignoreProfile`: Which `.stignore` profile to use — `"default"` or `"git-only"` (default: `"default"`)
  - `versioning`: Optional folder versioning configuration (set to `null` to disable)
  - `rescanIntervalS`: Full rescan interval in seconds (default: `14400` / 4 hours)
- `username`: Username for path construction (default: "mahdtech")
- `guiAddress`: Address for web GUI (default: "127.0.0.1:8384")

## Nested Folders

When using nested Syncthing folders (e.g. `~/Sync/` containing `~/Sync/Projects/`),
the parent folder's `.stignore` must exclude the child directory.
The `default` profile already ignores `Projects/` for this reason.

## Getting Device IDs

On each machine, run:

```bash
syncthing -device-id
```

Or start Syncthing and check the web interface at [http://127.0.0.1:8384](http://127.0.0.1:8384) under "Actions" → "Show ID"

## Folder Sync Types

- `sendreceive`: Bidirectional sync (default)
- `sendonly`: This device only sends changes
- `receiveonly`: This device only receives changes
- `receiveencrypted`: Receive-only with encryption

## Versioning Types

- `staggered`: Keep versions based on age (default)
- `simple`: Keep N versions
- `trashcan`: Move deleted files to trash
- `external`: Custom external command
- `null`: Disabled — no versioning (recommended for `git-only` folders)

Note: `{ }` does **not** disable versioning. home-manager types this option as
`nullOr (submodule { type = <required>; })`, so an empty attrset defines the
submodule without its mandatory `type` and evaluation fails with
`option ... versioning.type was accessed but has no value defined`.

## Adding More Machines

To add a third machine (MachineC):

1. Get MachineC's device ID
2. Add MachineC to the `otherDevices` list on MachineA and MachineB
3. Add MachineA and MachineB to the `otherDevices` list on MachineC
4. Update the `devices` list in `syncFolders` to include the new machine

## Example: Three Machines

```nix
# MachineA configuration
otherDevices = [
  { name = "MachineB"; id = "DEF456..."; }
  { name = "MachineC"; id = "GHI789..."; }
];

syncFolders = {
  "Shared" = {
    id = "shared-folder";
    path = "/home/user/Shared";
    devices = [ "MachineB" "MachineC" ];  # Sync with both
  };
};
```

This creates a fully connected mesh where all machines sync the Shared folder with each other.
