{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packaes = with pkgs;
    [
      awscli

      azure-cli
      azure-storae-azcopy

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

      nodePackaes.wrangler
    ]
    ++ unstablePkgs;
}
