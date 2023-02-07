{ config, lib, pkgs, ... }:

{

  xdg.configFile = {

    "mpv.conf" = {

      # Enabled hardware acceleration for VP9 on Intel GPUs
      target = "mpv/mpv.conf" ;

      text = ''

      hwdec=auto-safe
      vo=gpu
      profile=gpu-hq
      gpu-context=wayland

      '';

    };

  };

}
