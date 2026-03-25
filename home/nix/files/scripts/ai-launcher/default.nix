{
  config,
  pkgs,
  ...
}:
let
  aiPython = pkgs.python3.withPackages (
    p: with p; [
      huggingface-hub
      psutil
      pyyaml
      rich
    ]
  );

  # Copy the entire src directory as-is
  aiLauncherSrc = pkgs.stdenvNoCC.mkDerivation {
    name = "ai-launcher-src";
    src = ./src;
    installPhase = ''
      mkdir -p $out/lib/ai-launcher
      cp -r . $out/lib/ai-launcher/
    '';
  };
  # Expose gcc runtime lib path for pip-installed C extensions in venvs (NixOS FHS fix)
  gccLibPath = "${pkgs.stdenv.cc.cc.lib}/lib";
in
{
  home = {
    # Make sure vulkan-tools is installed so Python can query your GPU VRAM!
    packages = with pkgs; [
      mesa-demos
      vulkan-tools
    ];

    file = {
      # ai-launcher: start/stop AI model servers
      "ai-launcher" = {
        target = "${config.home.homeDirectory}/.local/bin/ai-launcher";
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          export PYTHONPATH="${aiLauncherSrc}/lib/ai-launcher:$PYTHONPATH"
          export LD_LIBRARY_PATH="${gccLibPath}:''${LD_LIBRARY_PATH:-}"
          exec ${aiPython}/bin/python3 ${aiLauncherSrc}/lib/ai-launcher/ai-launcher.py "$@"
        '';
      };

      # ai-voice: test voice models (open web UI, one-shot say)
      "ai-voice" = {
        target = "${config.home.homeDirectory}/.local/bin/ai-voice";
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          export PYTHONPATH="${aiLauncherSrc}/lib/ai-launcher:$PYTHONPATH"
          export LD_LIBRARY_PATH="${gccLibPath}:''${LD_LIBRARY_PATH:-}"
          exec ${aiPython}/bin/python3 ${aiLauncherSrc}/lib/ai-launcher/ai-voice.py "$@"
        '';
      };

      "ai-launcher-yaml" = {
        target = "${config.home.homeDirectory}/.local/bin/ai-launcher.yaml";
        source = ./src/ai-launcher.yaml;
      };
    };
  };
}
