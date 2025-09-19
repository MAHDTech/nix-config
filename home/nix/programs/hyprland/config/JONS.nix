##################################################
# JONS desktop monitor configuration
##################################################

# NOTES:
# - This desktop has dual displays
#   1. DP 40" Monitor (HP)
#   2. HDMI 32" Ultrawide Monitor (Alienware)
# - Manually specify monitor configs
# - Monitor descriptions put into variables for brevity

{
  monitorConfig = [
    # Let Hyprland automatically detect and configure the monitor
    #",preferred,auto,1"

    # HP 40" with DP connection (positioned below the Dell)
    "desc:HP Inc. HP Z43 CN49500228,3840x2160@59.99700,0x900,1.6,bitdepth,10"

    # Dell Alienware 32" with HDMI connection
    # Above the HP Monitor (center)
    "desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH,3440x1440@60,125x0,1.6,bitdepth,10"
  ];

  extraSettings = {
    # Desktop settings - can use standard gaps for large screen
    general = {
      gaps_in = 4;
      gaps_out = 4;
    };

    # Workspace rules for multi-monitor setup
    workspace = [
      # HP 40 is Workspace 1-5
      "1, name:1, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:true"
      "2, name:2, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "3, name:3, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "4, name:4, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "5, name:5, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"

      # Dell Alienware is Workspace 6-9
      "6, name:6, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "7, name:7, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "8, name:8, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "9, name:9, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
    ];

  };

}
