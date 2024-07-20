{
  inputs,
  pkgs,
  ...
}:
#########################
# NOTES:
#
#   - See https://nixos.wiki/wiki/Python
#   - This is for system level python packages.
#   - Virtualenvs can be used the normal way, ie:
#       python3 -m venv .venv
#   - Or, they can be defined in flake.nix the mach-nix way, ie:
#       nix-shell .#NAME
#########################
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];

  pythonPackages = pipPkg:
    with pipPkg; [
      pip
      virtualenv

      requests
    ];
in {
  home.packages = with pkgs; [(python3.withPackages pythonPackages)]; #++ unstablePkgs;
}
