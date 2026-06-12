##################################################
# ORION host monitor configuration
##################################################

{
  monitorConfig = [
    # Let Hyprland automatically detect and configure the monitor
    #",preferred,auto,1"

    # Dell Alienware 34" HDMI monitor gets Workspace 10 (displayed as 0)
    "desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH,3440x1440@60,125x0,1.6,bitdepth,10"
  ];

  extraSettings = {
    general = {
      gaps_in = 4;
      gaps_out = 4;
    };

    # Workspace rules to place all workspaces 1-10 on the Dell Alienware 34" monitor.
    workspace = [
      "1, name:1, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:true"
      "2, name:2, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "3, name:3, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "4, name:4, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "5, name:5, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "6, name:6, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "7, name:7, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "8, name:8, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "9, name:9, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
      "10, name:10, monitor:desc:Dell Inc. Dell AW3423DW ##GrMYMxgwABgH, persistent:true, default:false"
    ];
  };
}
