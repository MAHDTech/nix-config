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
      slack
      teams

      citrix_workspace

      vmware-horizon-client

      zoom-us
    ]
    ++ unstablePkgs;
}
