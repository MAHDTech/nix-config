##################################################
# JONS desktop monitor configuration
##################################################

# NOTES:
# - This desktop has dual displays
#   1. 40" Monitor (HP Z43 on DisplayPort)
#   2. 27" Monitor (MSI MP273A PB4H954500269 on HDMI)
# - Manually specify monitor configs
# - Monitor descriptions put into variables for brevity

{
  monitorConfig = [
    # Let Hyprland automatically detect and configure the monitor
    #",preferred,auto,1"

    # HP 40" with DP connection (positioned below the MSI)
    # Math:
    # - HP Z43 logical size: 3840x2160 / 1.6 = 2400x1350
    # - MSI MP273A logical size: 1920x1080 / 1.33 = ~1444x812
    #
    # - Vertical Alignment:
    #   MSI is on top starting at y = 0.
    #   HP is below MSI, so it starts at y = MSI_logical_height = 812.
    #
    # - Horizontal Alignment (MSI centered above HP):
    #   MSI x = (HP_logical_width - MSI_logical_width) / 2
    #   MSI x = (2400 - 1444) / 2 = 956 / 2 = 478.
    #   HP x = 0.
    #
    # Positions: MSI at 478x0, HP at 0x812
    "desc:HP Inc. HP Z43 CN49500228,3840x2160@59.99700,0x812,1.6,bitdepth,10"

    # MSI MP273A PB4H954500269
    # Above the HP Monitor (centered)
    "desc:Microstep MSI MP273A PB4H954500269,1920x1080@60,478x0,1.33,bitdepth,10"
  ];

  extraSettings = {
    # Desktop settings - can use standard gaps for large screen
    general = {
      gaps_in = 4;
      gaps_out = 4;
    };

    # Workspace rules for multi-monitor setup
    workspace = [
      # HP 40 is Workspace 1-9
      "1, name:1, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:true"
      "2, name:2, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "3, name:3, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "4, name:4, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "5, name:5, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "6, name:6, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "7, name:7, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "8, name:8, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "9, name:9, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"

      # MSI MP273A PB4H954500269
      "10, name:10, monitor:desc:Microstep MSI MP273A PB4H954500269, persistent:true, default:true"
    ];

  };

}
