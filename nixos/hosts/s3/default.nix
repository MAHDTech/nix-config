{ lib, ... }:
{
  imports = [
    ../../system/virtualisation/qemu-guest.nix
    ../../system/soe/nix
    ../../system/config/services/nixos-drain
    ../../system/config/services/rustfs/opnix.nix
    ../../system/config/services/rustfs/frontend.nix
  ];
  networking.hostName = "s3";
  services = {
    nixos-drain.enable = true;
    cloud-init.settings.preserve_hostname = true;
    journald.settings.Journal.SystemMaxUse = "1G";
    rustfs-managed = {
      enable = true;
      frontend = {
        enable = true;
        apiDomain = "s3.slopageddon.app";
        consoleDomain = "s3-console.slopageddon.app";
        cloudflareTokenReference = "op://fleet/Cloudflare ACME Slopageddon/token";
      };
      opnix = {
        enable = true;
        adminItem = "op://fleet/RustFS S3 Admin";
        writerItems = {
          github-actions = "op://fleet/RustFS GitHub Actions Writer";
          github-packages = "op://fleet/RustFS GitHub Packages Writer";
        };
      };
      buckets = {
        github-actions = {
          publicRead = true;
          retentionDays = 30;
        };
        github-packages = {
          publicRead = true;
          retentionDays = 30;
        };
      };
      writers = {
        github-actions.buckets = [ "github-actions" ];
        github-packages.buckets = [ "github-packages" ];
      };
    };
  };
  system.autoUpgrade = {
    flake = lib.mkForce "github:MAHDTech/nix-config#s3";
    operation = lib.mkForce "switch";
    allowReboot = lib.mkForce false;
  };
  systemd.services.nixos-upgrade = {
    preStart = "/run/current-system/sw/bin/nixos-drain drain --profile upgrade";
    postStart = "/run/current-system/sw/bin/nixos-drain cancel";
  };
  nix.settings.trusted-users = lib.mkForce [ "root" ];
}
