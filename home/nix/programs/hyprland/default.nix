{
  lib,
  inCI,
  osConfig ? { },
  ...
}:
let
  # Get hostname for conditional configuration
  # When running as NixOS module, use osConfig, otherwise fallback to file
  hostname =
    if
      osConfig != null
      && builtins.hasAttr "networking" osConfig
      && builtins.hasAttr "hostName" osConfig.networking
    then
      osConfig.networking.hostName
    else
      (lib.fileContents /proc/sys/kernel/hostname);

  # Determine which device config to load based on hostname
  # Get the monitor names with 'hyprctl monitors'
  deviceConfigPath =
    if lib.hasInfix "JONS" hostname then
      ./config/JONS.nix
    else if lib.hasInfix "NUC" hostname then
      ./config/NUC.nix
    else if lib.hasInfix "ZENBOOK" hostname then
      ./config/ZENBOOK.nix
    else if lib.hasInfix "ORION" hostname then
      ./config/ORION.nix
    else
      ./config/default.nix;

  # Load the appropriate device configuration
  deviceConfig = import deviceConfigPath;
in
{
  imports = [
    ./hyprland.nix
  ]
  ++ lib.optional (!inCI) ./bar
  ++ lib.optional (!inCI) ./runner;

  # Pass the device configuration to hyprland.nix
  _module.args.deviceConfig = deviceConfig;
}
