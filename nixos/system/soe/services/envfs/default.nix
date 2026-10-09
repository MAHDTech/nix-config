{ pkgs, ... }:
{
  services.envfs = {
    enable = true;
    extraFallbackPathCommands = ''
      ln -s ${pkgs.bash}/bin/bash $out/bash
    '';
  };
}
