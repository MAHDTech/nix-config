{
  inputs,
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

      kind
      krew
      kubectl
      kubernetes-helm
      kustomize
      kustomize-sops
      octant

      packer

      pulumi-bin

      podman
      buildah
      skopeo
      dive

      terraform
      terraform-docs
      terraform-ls
      tflint
      tfsec

      wrangler_1
    ]
    ++ unstablePkgs;
}
