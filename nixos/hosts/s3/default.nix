{ lib, ... }:
{
  imports = [
    ../../system/virtualisation/qemu-guest.nix
    ../../system/soe/nix
    ../../system/config/services/rustfs/opnix.nix
    ../../system/config/services/rustfs/frontend.nix
  ];
  networking.hostName = "s3";
  services = {
    cloud-init.settings.preserve_hostname = true;
    journald.settings.Journal.SystemMaxUse = "1G";
    rustfs-managed = {
      enable = true;
      frontend = {
        enable = true;
        apiDomain = "s3.slopageddon.app";
        consoleDomain = "s3-console.slopageddon.app";
        cloudflareTokenReference = "op://machines/Cloudflare ACME Slopageddon/token";
      };
      opnix = {
        enable = true;
        adminItem = "op://machines/RustFS S3 Admin";
        writerItems = {
          github-actions = "op://machines/RustFS GitHub Actions Writer";
          github-packages = "op://machines/RustFS GitHub Packages Writer";
          terraform-state-bingamon = "op://machines/RustFS Terraform State Bingamon";
          terraform-state-bingamon-nkp = "op://machines/RustFS Terraform State Bingamon NKP";
          terraform-state-big-stack-iac = "op://machines/RustFS Terraform State Big Stack IAC";
        };
      };
      buckets = {
        terraform-state-bingamon = {
          publicRead = false;
          retentionDays = null;
        };
        terraform-state-bingamon-nkp = {
          publicRead = false;
          retentionDays = null;
        };
        terraform-state-big-stack-iac = {
          publicRead = false;
          retentionDays = null;
        };
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
        terraform-state-bingamon.buckets = [ "terraform-state-bingamon" ];
        terraform-state-bingamon-nkp.buckets = [ "terraform-state-bingamon-nkp" ];
        terraform-state-big-stack-iac.buckets = [ "terraform-state-big-stack-iac" ];
      };
    };
  };
  system.autoUpgrade = {
    flake = lib.mkForce "github:MAHDTech/nix-config#s3";
  };
  nix.settings.trusted-users = lib.mkForce [ "root" ];
}
