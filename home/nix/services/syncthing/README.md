# Syncthing Configuration

This dynamic Syncthing module allows you to configure any number of machines to sync with each other by passing parameters.

## How It Works

Each machine gets configured with:

- Its own device name and ID
- A list of other devices it should connect to
- A list of folders to sync

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
    {
      name = "MachineC";
      id = "GHI789...";  # MachineC's device ID
      autoAcceptFolders = false;
    }
  ];
  syncFolders = {
    "Documents" = {
      id = "docs-shared";
      path = "/home/user/Documents";
      type = "sendreceive";
      devices = [ "MachineB" "MachineC" ];
      versioning = {
        type = "simple";
        params = {
          keep = "20";
        };
      };
    };
    "Photos" = {
      id = "photos-shared";
      path = "/home/user/Photos";
      type = "sendreceive";
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
  - `versioning`: Optional folder versioning configuration
  - `rescanIntervalS`: Full rescan interval in seconds (default: `86400` / 24 hours)
- `username`: Username for path construction (default: "mahdtech")
- `guiAddress`: Address for web GUI (default: "127.0.0.1:8384")

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

- `simple`: Keep N versions
- `staggered`: Keep versions based on age
- `trashcan`: Move deleted files to trash
- `external`: Custom external command

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
