{
  inputs,
  pkgs,
  lib,
  osConfig ? { },
  ...
}:
let
  # Get hostname for conditional configuration
  hostname =
    if
      osConfig != null
      && builtins.hasAttr "networking" osConfig
      && builtins.hasAttr "hostName" osConfig.networking
    then
      osConfig.networking.hostName
    else
      "";

  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  unstablePkgs = with pkgsUnstable; [
    ironbar # v0.18+ is GTK4
  ];

  # Determine which config file to source based on host
  configFile =
    if lib.hasInfix "ZENBOOK" hostname then
      ./config-ZENBOOK.yaml
    else if lib.hasInfix "JONS" hostname then
      ./config-JONS.yaml
    else if lib.hasInfix "ORION" hostname then
      ./config-ORION.yaml
    else
      ./config.yaml; # Fallback
in
{
  home.packages =
    with pkgs;
    [
      zafiro-icons
    ]
    ++ unstablePkgs;

  xdg = {
    configFile = {
      "ironbar-config" = {
        source = configFile;
        target = "ironbar/config.yaml";
        onChange = "pgrep ironbar && ${pkgs.ironbar}/bin/ironbar reload || true";
      };

      "ironbar-style" = {
        source = ./style.css;
        target = "ironbar/style.css";
        onChange = "pgrep ironbar && ${pkgs.ironbar}/bin/ironbar reload || true";
      };

      "ironbar-scripts" = {
        source = ./scripts;
        target = "ironbar/scripts";
        onChange = "pgrep ironbar && ${pkgs.ironbar}/bin/ironbar reload || true";
      };
    };
  };
}
