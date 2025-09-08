{
  inputs,
  pkgs,
  ...
}:
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  # System common packages.
  systemCommonPackages = [
    # slack
    # teams
    # vmware-horizon-client
    # zoom-us
  ];

  # System architecture specific packages.
  systemArchPackages =
    if pkgs.system == "x86_64-linux" then
      [
        # x86_64 only packages.
        # https://militarycac.com/linux.html
        # nix-prefetch-url file://$PWD/linuxx64-25.05.0.44.tar.gz
        pkgsUnstable.citrix_workspace
      ]
    else if pkgs.system == "aarch64-linux" then
      [
        # aarch64 only packages.
      ]
    else
      [ ];

  allPackages = systemCommonPackages ++ systemArchPackages;

in
{
  home.packages = allPackages;
}
