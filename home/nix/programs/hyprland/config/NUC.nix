##################################################
# NUC laptop monitor configuration
##################################################

# NOTES:
# - This laptop has 3 displays
# - 1x Laptop Monitor (BOE)
# - 1x DP Ultrawide Monitor (Kogan)
# - 1x HDMI Ultrawide Monitor (DELL)
# - Manually specify monitor configs
# - Monitor descriptions put into variables for brevity

{
  monitorConfig = [
    # Let Hyprland automatically detect and configure the monitor
    #",preferred,auto,1"

    # Laptop Monitor
    "desc:BOE 0x084D,1920x1080@144,0x0,1.6,bitdepth,10"

    # Kogan Monitor underneath Laptop Monitor (DP connection)
    "desc:KOGAN AUSTRALIA PTY LTD KAMN49QDQUCLA 0000000000000,5120x1440@60,450x675,1.6,bitdepth,10"

    # Dell Alienware Monitor to the right of Laptop Monitor (HDMI connection)
    # Raise the Alienware Monitor up just a bit to compensate for the
    # smaller resolution of the Laptop Monitor.
    # 1080 - 1440 = 360
    # 360 / 1.6 = 225
    "desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH,3440x1440@60,1200x-225,1.6,bitdepth,10"
  ];

  extraSettings = {
    # Laptop-specific settings - smaller gaps for mobile use
    general = {
      gaps_in = 2;
      gaps_out = 2;
    };

    # Workspace rules for multi-monitor setup
    workspace = [
      # Laptop Monitor is Workspace 1
      "1, name:1, monitor:desc:BOE 0x084D, persistent:true, default:true"

      # Kogan Monitor is Workspace 2-5
      "2, name:2, monitor:desc:KOGAN AUSTRALIA PTY LTD KAMN49QDQUCLA 0000000000000, persistent:true, default:true"
      "3, name:3, monitor:desc:KOGAN AUSTRALIA PTY LTD KAMN49QDQUCLA 0000000000000, persistent:true, default:false"
      "4, name:4, monitor:desc:KOGAN AUSTRALIA PTY LTD KAMN49QDQUCLA 0000000000000, persistent:true, default:false"
      "5, name:5, monitor:desc:KOGAN AUSTRALIA PTY LTD KAMN49QDQUCLA 0000000000000, persistent:true, default:false"

      # Dell Alienware Monitor is Workspace 6-9
      "6, name:6, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:true"
      "7, name:7, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "8, name:8, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "9, name:9, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
    ];
  };
}
