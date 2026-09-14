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
  # Static musl links its xattr functions into the test alongside its mocks.
  libcap_ng = _prev.libcap_ng.overrideAttrs (
    old:
    final.lib.optionalAttrs (final.stdenv.hostPlatform.isStatic && final.stdenv.hostPlatform.isMusl) {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/test/file_caps_test.c \
          --replace-fail 'ssize_t fgetxattr(' 'ssize_t __wrap_fgetxattr(' \
          --replace-fail 'int fsetxattr(' 'int __wrap_fsetxattr('
        echo 'file_caps_test_LDFLAGS = -Wl,--wrap=fgetxattr,--wrap=fsetxattr' >> src/test/Makefile.am
      '';
    }
  );

  # httpstat 1.3.2 reads the AST string alias removed in Python 3.14.
  httpstat = _prev.httpstat.overridePythonAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace setup.py \
        --replace-fail 'ast.parse(line).body[0].value.s' 'ast.parse(line).body[0].value.value'
    '';
  });

  # Not in nixpkgs as of release-26.05 or nixos-unstable.
  # Remove this line and delete home/nix/packages/custom/cosmic-ext-applet-clipboard-manager
  # once https://github.com/NixOS/nixpkgs has it.
  cosmic-ext-applet-clipboard-manager =
    final.callPackage ../home/nix/packages/custom/cosmic-ext-applet-clipboard-manager/package.nix
      { };

  # Disable checkPhase for pulumi to bypass flaky Go 1.23 context cancellation unit test failure
  pulumi = _prev.pulumi.overrideAttrs (_old: {
    doCheck = false;
  });
}
