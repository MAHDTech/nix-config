{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  # Pull crane from the global NixOS flake inputs passed via extraSpecialArgs
  crane = inputs.crane.mkLib pkgs;

  # Clean source path. Ensure Cargo.lock is generated and tracked by git later!
  src = crane.cleanCargoSource ./.;

  # Shared build arguments
  commonArgs = {
    inherit src;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl.dev ];
  };

  # Build the dependency artifacts to cache them
  cargoArtifacts = crane.buildDepsOnly commonArgs;

  # Build the main binary
  burn-launcher = crane.buildPackage (commonArgs // {
    inherit cargoArtifacts;
  });

  # Make Vulkan and generic cc libraries available for WGPU detection
  wgpuLibPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.vulkan-loader
  ];

in
{
  home = {
    packages = with pkgs; [
      mesa-demos
      vulkan-tools
    ];

    file."burn-launcher" = {
      target = "${config.home.homeDirectory}/.local/bin/burn-launcher";
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        export LD_LIBRARY_PATH="${wgpuLibPath}:''${LD_LIBRARY_PATH:-}"
        exec ${burn-launcher}/bin/burn-launcher "$@"
      '';
    };
  };
}
