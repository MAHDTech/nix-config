##################################################
# ZENBOOK laptop monitor configuration
##################################################

# Samsung ATNA40CT06-0 built-in OLED (eDP-1)
# HP Inc. HP Z43 Z-series 40" 4K (Dock DP)
# Dell Inc. Dell AW3423DW Alienware 34" Ultrawide (Dock HDMI)

{
  monitorConfig = [
    # Let Hyprland automatically detect and configure the monitor
    #",preferred,auto,1"

    # Built-in Zenbook display (eDP-1) gets Workspace 1
    # Center-bottom position below HP monitor when docked (HP starts at y=900, height 2160/1.6=1350, so HP ends at y=2250)
    # HP scaled width: 3840 / 1.6 = 2400. Zenbook scaled width: 1920 / 1.25 = 1536. Centering x-offset: (2400 - 1536) / 2 = 432.
    "desc:Samsung Display Corp. ATNA40CT06-0,1920x1200@60.00300,432x2250,1.25,bitdepth,10"

    # HP 40" DP monitor gets Workspaces 2-9
    "desc:HP Inc. HP Z43 CN49500228,3840x2160@59.99700,0x900,1.6,bitdepth,10"

    # Dell Alienware 34" HDMI monitor gets Workspace 10 (displayed as 0)
    "desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH,3440x1440@60,125x0,1.6,bitdepth,10"
  ];

  extraSettings = {
    general = {
      gaps_in = 4;
      gaps_out = 4;
    };

    workspace = [
      # Built-in Zenbook display is Workspace 1
      "1, name:1, monitor:desc:Samsung Display Corp. ATNA40CT06-0, persistent:true, default:true"

      # HP 40 is Workspaces 2-9
      "2, name:2, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:true"
      "3, name:3, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "4, name:4, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "5, name:5, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "6, name:6, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "7, name:7, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "8, name:8, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"
      "9, name:9, monitor:desc:HP Inc. HP Z43 CN49500228, persistent:true, default:false"

      # Dell Alienware is Workspace 10 (displayed as 0)
      "10, name:10, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:true"
    ];
  };
}
