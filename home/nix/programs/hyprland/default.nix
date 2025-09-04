{
  config,
  lib,
  inGitHubActions,
  ...
}:
let
  # Get hostname for conditional configuration
  hostname = config.networking.hostName or (lib.fileContents /proc/sys/kernel/hostname);

  # Determine which device config to load based on hostname
  deviceConfigPath =
    if lib.hasInfix "JONS" hostname then
      ./config/JONS.nix
    else if lib.hasInfix "NUC" hostname then
      ./config/NUC.nix
    else if lib.hasInfix "ZENBOOK" hostname then
      ./config/ZENBOOK.nix
    else
      ./config/default.nix;

  # Load the appropriate device configuration
  deviceConfig = import deviceConfigPath;
in
{
  imports = [
    ./hyprland.nix
  ]
  ++ lib.optional (!inGitHubActions) ./bar;

  # Pass the device configuration to hyprland.nix
  _module.args.deviceConfig = deviceConfig;
}
