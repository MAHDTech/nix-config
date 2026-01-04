{
  pkgs,
  ...
}:
{

  environment = {
    variables = {
      MANGOHUD_CONFIG = "cpu_stats,gpu_stats,ram,vram,core_load,fps";
      ANV_ENABLE_PIPELINE_CACHE = "1";
    };
  };

  programs = {
    gamemode = {
      enable = true;
      enableRenice = true;
      settings = {
        general = {
          renice = 10;
          softrealtime = "read-time";
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_device = "no";
        };
        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
        };
        system = {
          governor = "performance";
        };
      };
    };
    steam = {
      enable = true;
      package = pkgs.steam.override {
        extraPkgs =
          pkgs: with pkgs; [
            mangohud # FPS Overlay
            gamescope # Steam Overlay
            gamemode # GameMode
            vulkan-tools # 'vulkaninfo'
            libva-utils # 'vainfo'
          ];
      };
      remotePlay = {
        openFirewall = true;
      };
      protontricks = {
        enable = true;
      };
      gamescopeSession = {
        enable = true;
      };
      extest = {
        enable = true;
      };
      dedicatedServer = {
        openFirewall = true;
      };
    };
  };

  # Allow ports required for Steam Link.
  networking = {
    firewall = {
      allowedUDPPorts = [
        27031
        27036
      ];
      allowedTCPPorts = [
        27036
        27037
      ];
    };
  };

}
