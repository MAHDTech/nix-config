{ lib, pkgs, ... }:
let
  fleet = (import ../fleet.nix).beszel;
in
{
  imports = [
    ../../system/virtualisation/qemu-guest.nix
    ../../system/soe/nix
    ../../system/config/services/nixos-drain
    ../../system/config/services/beszel/hub
  ];
  networking.hostName = "hub";
  services = {
    cloud-init.settings.preserve_hostname = true;
    journald.settings.Journal.SystemMaxUse = "1G";
    nixos-drain.enable = true;
    beszel.hub = {
      enable = true;
      environment = {
        DISABLE_PASSWORD_AUTH = "true";
        USER_CREATION = "true";
        SHARE_ALL_SYSTEMS = "true";
        CHECK_UPDATES = "false";
        CONTAINER_DETAILS = "false";
      };
      systems = lib.mapAttrs (_: member: { inherit (member) host; }) fleet.members;
      opnix = {
        enable = true;
        privateKeyReference = "op://fleet/Beszel Hub/private_key";
        bootstrapReference = "op://fleet/Beszel Hub/bootstrap_environment";
        tokenReferences = lib.mapAttrs (_: member: member.tokenReference) fleet.members;
      };
      frontend = {
        enable = true;
        domain = "hub.slopageddon.app";
        cloudflareTokenReference = "op://fleet/Cloudflare ACME Slopageddon/token";
      };
    };
  };
  system.autoUpgrade = {
    flake = lib.mkForce "github:MAHDTech/nix-config#hub";
    operation = lib.mkForce "switch";
    allowReboot = lib.mkForce false;
  };
  systemd.services = {
    nixos-upgrade = {
      preStart = "/run/current-system/sw/bin/nixos-drain drain --profile upgrade";
      postStart = "/run/current-system/sw/bin/nixos-drain cancel";
    };
    opnix-secrets = {
      wants = [ "cloud-final.service" ];
      after = [ "cloud-final.service" ];
      unitConfig.StartLimitIntervalSec = lib.mkForce 0;
      serviceConfig = {
        RestartPreventExitStatus = lib.mkForce [ ];
        RestartSec = lib.mkForce "1min";
        TimeoutStartSec = "infinity";
      };
      preStart = ''
        while [ ! -s /etc/opnix-token ]; do
          echo "Waiting for the Opnix service-account token"
          ${pkgs.coreutils}/bin/sleep 30
        done
      '';
    };
  };
  nix.settings.trusted-users = lib.mkForce [ "root" ];
}
