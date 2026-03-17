{
  config,
  pkgs,
  ...
}:
let
  aiPython = pkgs.python3.withPackages (
    p: with p; [
      huggingface-hub
      rich
      psutil
      pyyaml
    ]
  );
in
{
  home = {
    # Make sure vulkan-tools is installed so Python can query your GPU VRAM!
    packages = with pkgs; [
      mesa-demos
      vulkan-tools
    ];

    file."ai-launcher" = {
      target = "${config.home.homeDirectory}/.local/bin/ai-launcher";
      executable = true;

      # This dynamically injects the isolated Python path into your raw Python file
      text = ''
        #!${aiPython}/bin/python3
      ''
      + builtins.readFile ./src/ai-launcher.py;
    };

    file."ai-launcher-yaml" = {
      target = "${config.home.homeDirectory}/.local/bin/ai-launcher.yaml";
      source = ./src/ai-launcher.yaml;
    };
  };
}
