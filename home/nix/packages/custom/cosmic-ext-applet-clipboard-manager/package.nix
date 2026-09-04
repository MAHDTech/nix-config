##################################################
# COSMIC Clipboard Manager applet
##################################################

# NOTES:
#   - COSMIC ships no clipboard manager of its own: cosmic-comp owns the
#     selection directly, so nothing persists history and there is no service
#     to restart. This applet fills that gap as a real panel plugin.
#   - This package is NOT in nixpkgs (checked against both release-26.05 and
#     nixos-unstable). It is exposed through ../../../../overlays so that every
#     consumer refers to it only as `pkgs.cosmic-ext-applet-clipboard-manager`.
#     When it lands in nixpkgs, delete this directory and the single line in
#     overlays/default.nix — nothing else needs to change.
#   - Structured to mirror nixpkgs' cosmic-ext-tweaks derivation so the eventual
#     upstream package is a drop-in replacement.
#   - Requires the ext-data-control-v1 Wayland protocol, which COSMIC only
#     exposes when COSMIC_DATA_CONTROL_ENABLED=1 is set. That is done in
#     nixos/system/config/desktop-environment/cosmic.nix.

{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  libcosmicAppHook,
  just,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cosmic-ext-applet-clipboard-manager";
  version = "0.1.0-unstable-2026-03-24";

  src = fetchFromGitHub {
    owner = "cosmic-utils";
    repo = "clipboard-manager";
    # The 0.1.0 tag is from 2024-11 and 81 commits behind; it predates
    # COSMIC 1.x and does not build against the current libcosmic.
    rev = "d473e8f09e8bc2289a76707898063a13714c79dc";
    hash = "sha256-RNRSShrT7wS4GmQNd3tXtT8G/4qLM9zxntXgBQ6C7ps=";
  };

  cargoHash = "sha256-+yqFV8HdPjkVny+6FKkZFEQAq1rwe7JXmoTJ7zge8bg=";

  # The justfile's first line is
  #   export CLIPBOARD_MANAGER_COMMIT := `git rev-parse --short HEAD`
  # which just evaluates at parse time. There is no git repo (or git binary) in
  # the build sandbox, so even `just install` would fail. build.rs treats the
  # variable as optional, so substituting any literal is fine.
  postPatch = ''
    substituteInPlace justfile \
      --replace-fail '`git rev-parse --short HEAD`' "'${builtins.substring 0 7 finalAttrs.src.rev}'"
  '';

  separateDebugInfo = true;

  nativeBuildInputs = [
    # Provides libxkbcommon, libGL, wayland, vulkan-loader and the wrapper that
    # sets the COSMIC icon/theme search paths.
    libcosmicAppHook
    just
  ];

  # cargo does the building; just is only used for its install recipe.
  dontUseJustBuild = true;
  dontUseJustCheck = true;

  justFlags = [
    "--set"
    "prefix"
    (placeholder "out")
    "--set"
    "bin-src"
    "target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/${finalAttrs.pname}"
  ];

  meta = {
    description = "Clipboard manager applet for the COSMIC Desktop Environment";
    homepage = "https://github.com/cosmic-utils/clipboard-manager";
    license = lib.licenses.gpl3Only;
    mainProgram = "cosmic-ext-applet-clipboard-manager";
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
