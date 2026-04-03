# Wallpaper Manager Service

This directory contains the configuration for a systemd user service that manages both `awww-daemon` and a random wallpaper rotation in a single integrated script.

## Components

### 1. `script.nix`

Creates the main `wallpaper-manager` script that:

- Starts `awww-daemon` if not already running
- Waits for awww to be ready
- Manages a wallpaper rotation loop
- Logs to the systemd journal
- Rotates wallpapers every 15 minutes (configurable)
- Supports multiple displays

### 2. `systemd.nix`

Configures the systemd user service that:

- Starts after `hyprland-session.target` is active
- Automatically restarts on failure
- Logs to the systemd journal
- Has proper environment variables set

### 3. `default.nix`

Entry point that imports the script and systemd configurations.

## Systemd Service

The `wallpaper-manager` service is configured and:

- Starts after `hyprland-session.target` is active
- Automatically restarts on failure
- Logs to the systemd journal
- Has proper environment variables set
- Includes clean shutdown handling

## Usage

### Automatic Start

The service starts automatically when you log into Hyprland and the `hyprland-session.target` becomes active.

### Manual Control

```bash
# Start the service
systemctl --user start wallpaper-manager.service

# Stop the service
systemctl --user stop wallpaper-manager.service

# Restart the service
systemctl --user restart wallpaper-manager.service

# Check status
systemctl --user status wallpaper-manager.service

# View logs
journalctl --user -u wallpaper-manager.service -f
```

## Configuration

### Wallpaper Directory

Set the `XDG_WALLPAPERS_DIR` environment variable or use the default `~/Pictures/Wallpapers`.

### Rotation Interval

The wallpaper rotates every 15 minutes (900 seconds). This can be modified in the `script.nix` file.

### Display Support

The script automatically detects and manages wallpapers for all connected displays.

## Troubleshooting

### Check Service Status

```bash
systemctl --user status wallpaper-manager.service
```

### View Recent Logs

```bash
journalctl --user -u wallpaper-manager.service --since "1 hour ago"
```

### Check if awww is Running

```bash
pgrep -x awww-daemon
awww query
```

### Manual Test

```bash
# Test the wallpaper manager script directly
~/.local/bin/wallpaper-manager
```

## Migration from Previous Setup

The following changes were made to consolidate the wallpaper management:

1. **Merged scripts**: Combined `awww-daemon` startup and `random-wallpaper` into a single `wallpaper-manager` script
2. **Single systemd service**: One service manages both the daemon and wallpaper rotation
3. **Unified logging**: All logs go to systemd journal with consistent tagging
4. **Simplified structure**: Four files instead of multiple scattered configurations

## Dependencies

- `awww` package (already included in hyprland packages)
- `systemd` (standard on NixOS)
- `bash` (standard shell)
- `find`, `shuf`, `grep` (standard Unix tools)

## File Structure

```bash
wallpaper-manager/
├── README.md          # This documentation
├── default.nix        # Imports script and systemd configs
├── script.nix         # Creates the wallpaper-manager script
└── systemd.nix        # Systemd user service configuration
```
