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

    # HP 40" with DP connection (positioned below the Dell)
    "desc:HP Inc. HP Z43 CN49500228,3840x2160@59.99700,0x900,1.6,bitdepth,10"

    # MSI MP273A PB4H954500269
    # Above the HP Monitor (center)
    "desc:Microstep MSI MP273A PB4H954500269,1920x1080@60,125x0,1.6,bitdepth,10"
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
