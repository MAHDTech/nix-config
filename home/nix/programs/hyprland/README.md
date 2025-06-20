# Hyprland Dynamic Configuration

This Hyprland configuration uses a hybrid approach to handle different monitor setups across multiple systems.

## How it Works

The configuration dynamically loads device-specific settings based on the system hostname:

- **JONS**: Desktop with single display (auto-detection)
- **NUC**: Laptop with 3 displays (manual configuration)
- **Default**: Fallback for unknown hostnames (auto-detection)

## Structure

```shell
hyprland/
├── default.nix          # Main entry point with hostname detection
├── hyprland.nix         # Common Hyprland configuration
├── ags.nix              # AGS configuration
├── config/
│   ├── JONS.nix         # Desktop configuration
│   ├── NUC.nix          # Laptop configuration
│   └── default.nix      # Fallback configuration
└── test-hostname.nix    # Debug script for hostname detection
```

## Configuration Files

Each configuration file in `config/` exports:

```nix
{
  monitorConfig = [
    # List of monitor configurations for hyprctl
  ];

  extraSettings = {
    general = {
      gaps_in = 4;    # Window gaps
      gaps_out = 4;
    };

    workspace = [
      # Optional workspace rules for multi-monitor setups
    ];
  };
}
```

## Testing

To test hostname detection:

```bash
cd home/nix/programs/hyprland
nix-instantiate --eval test-hostname.nix
```

## Adding New Systems

1. Create a new file in `config/` (e.g., `NEW-HOSTNAME.nix`)
2. Add the hostname condition to `default.nix`
3. Define monitor configuration and settings in the new file

## Monitor Configuration Examples

### Auto-detection (JONS, default)

```nix
monitorConfig = [
  ",preferred,auto,1"    # Let Hyprland auto-detect
];
```

### Manual configuration (NUC)

```nix
monitorConfig = [
  "desc:BOE 0x084D,1920x1080@144,0x0,1.6,bitdepth,10"
  "desc:KOGAN...,5120x1440@60,450x675,1.6,bitdepth,10"
  "desc:Dell Inc...,3440x1440@60,1200x-225,1.6,bitdepth,10"
];
```

## Benefits

- **Nix-native**: Configuration determined at build time
- **Clean separation**: Device-specific configs in separate files
- **Fallback support**: Unknown systems get auto-detection
- **Maintainable**: Easy to add new systems or modify existing ones
- **Performance**: No runtime hostname detection overhead
