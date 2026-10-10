{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.system.autoUpgrade;
  # nixpkgs appends a shell-fragment flake flag; pass our own quoted arguments.
  flags = builtins.filter (flag: flag != "--refresh" && flag != "--flake ${cfg.flake}") cfg.flags;
in
{
  imports = [
    ../nixos-drain
    ../nginx/graceful.nix
  ];
  services.nixos-drain.enable = true;
  system.autoUpgrade = {
    operation = lib.mkDefault "boot";
    allowReboot = lib.mkDefault true;
    rebootWindow = lib.mkDefault null;
  };
  systemd.services.nixos-upgrade = lib.mkIf cfg.enable {
    path = [
      config.system.build.nixos-rebuild
      pkgs.coreutils
      config.systemd.package
      (import ../nixos-drain/package.nix { inherit pkgs; })
    ];
    serviceConfig.TimeoutStartSec = lib.mkForce (
      7200 + 2 * config.services.nixos-drain.profiles.upgrade.timeoutSeconds + 60
    );
    serviceConfig.TimeoutStopSec = 2 * config.services.nixos-drain.profiles.upgrade.timeoutSeconds + 60;
    script = lib.mkForce (
      if cfg.allowReboot then
        ''
          exec ${pkgs.bash}/bin/bash ${./upgrade.sh} --flake ${lib.escapeShellArg cfg.flake} ${lib.escapeShellArgs flags}
        ''
      else
        ''
          exec ${config.system.build.nixos-rebuild}/bin/nixos-rebuild ${cfg.operation} --flake ${lib.escapeShellArg cfg.flake} ${lib.escapeShellArgs flags}
        ''
    );
  };
  assertions = [
    {
      assertion = !cfg.enable || cfg.flake != null;
      message = "Managed host upgrades require system.autoUpgrade.flake.";
    }
  ];
}
