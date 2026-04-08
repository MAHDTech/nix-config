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

  yamlFilter = path: _type: builtins.match ".*/home/nix/files/scripts/.*yaml$" path != null;
  yamlOrCargo = path: type: (yamlFilter path type) || (crane.filterCargoSources path type);

  # Extract the entire workspace from the root, allowing full traversal of global lockfiles
  src = lib.cleanSourceWith {
    src = ../../../../..;
    filter = yamlOrCargo;
  };

  # Shared build arguments
  commonArgs = {
    pname = "burn-lm-launcher";
    version = "0.1.0";
    inherit src;
    strictDeps = true;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl.dev ];
  };

  # Build the dependency artifacts globally across the workspace
  cargoArtifacts = crane.buildDepsOnly commonArgs;

  # Build the main binary isolated via cargo arg constraints
  burn-lm-launcher = crane.buildPackage (
    commonArgs
    // {
      inherit cargoArtifacts;
      cargoExtraArgs = "-p burn-lm-launcher";
    }
  );

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

    file."burn-lm-launcher" = {
      target = "${config.home.homeDirectory}/.local/bin/burn-lm-launcher";
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        export LD_LIBRARY_PATH="${wgpuLibPath}:''${LD_LIBRARY_PATH:-}"
        exec ${burn-lm-launcher}/bin/burn-lm-launcher "$@"
      '';
    };
  };
}
