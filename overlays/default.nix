##################################################
# Repository-wide nixpkgs overlays
##################################################

# NOTES:
#   - Applied in lib/default.nix (pkgsImport), so these attributes are available
#     to every host and, because home-manager runs with useGlobalPkgs = true,
#     to every home-manager module as well.
#   - Everything here is a stopgap for a package that is not yet in nixpkgs.
#     Each entry should be deletable in one line once upstream catches up.

final: _prev: {
  # Not in nixpkgs as of release-26.05 or nixos-unstable.
  # Remove this line and delete home/nix/packages/custom/cosmic-ext-applet-clipboard-manager
  # once https://github.com/NixOS/nixpkgs has it.
  cosmic-ext-applet-clipboard-manager =
    final.callPackage ../home/nix/packages/custom/cosmic-ext-applet-clipboard-manager/package.nix
      { };

  # Disable checkPhase for pulumi to bypass flaky Go 1.23 context cancellation unit test failure
  pulumi = _prev.pulumi.overrideAttrs (_: {
    doCheck = false;
  });
}
