{
  inputs,
  pkgs,
  ...
}:
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [
    # https://militarycac.com/linux.html
    # nix-prefetch-url file://$PWD/linuxx64-25.05.0.44.tar.gz
    citrix_workspace # 25.05.0.44
  ];
in
{
  home.packages = unstablePkgs;
  #  with pkgs;
  #  [
  #    #slack
  #    #teams
  #
  #    #citrix_workspace v24.x
  #
  #    #vmware-horizon-client
  #
  #    #zoom-us
  #  ]
  #   ++ unstablePkgs;
}
