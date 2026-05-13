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
      localNetworkGameTransfers.openFirewall = true;

      # Use the module-level extraPackages which correctly handles 32-bit/64-bit merging.
      extraPackages = with pkgs; [
        mangohud # FPS Overlay
        gamescope # Steam Overlay
        gamemode # GameMode
        vulkan-tools # 'vulkaninfo'
        libva-utils # 'vainfo'
        openssl
        libkrb5
        keyutils
        curl
        glib
        glib-networking
        dbus-glib
        networkmanager # Essential for Steam's connectivity checks
        systemd # Provides nss-resolve for DNS inside the FHS sandbox
      ];

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

  # Steam Firewall Rules
  networking.firewall = {
    allowedTCPPortRanges = [
      {
        from = 27014;
        to = 27050;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 27000;
        to = 27100;
      }
    ];
  };

  # Gamescope and Steam Link configuration are handled above.
}
