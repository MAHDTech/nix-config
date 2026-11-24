let
  fleet = import ../fleet.nix;
in
{
  imports = [
    ../common/appliance.nix
    ../../system/config/services/rustfs/opnix.nix
    ../../system/config/services/rustfs/frontend.nix
  ];
  services.rustfs-managed = {
    enable = true;
    frontend = {
      enable = true;
      apiDomain = "s3.${fleet.domain}";
      consoleDomain = "s3-console.${fleet.domain}";
      cloudflareTokenReference = fleet.acme.tokenReference;
      cloudflareEmail = fleet.acme.email;
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
        versioning = true;
      };
      terraform-state-bingamon-nkp = {
        publicRead = false;
        retentionDays = null;
        versioning = true;
      };
      terraform-state-big-stack-iac = {
        publicRead = false;
        retentionDays = null;
        versioning = true;
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
}
