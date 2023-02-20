{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs;
    [
      awscli

      azure-cli
      azure-storage-azcopy

      google-cloud-sdk

      kubectl

      packer

      pulumi-bin

      terraform
      terraform-docs
      terraform-ls
      tflint
      tfsec
    ]
    ++ unstablePkgs;
}
