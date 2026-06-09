##################################################
# ORION host monitor configuration
##################################################

{
  monitorConfig = [
    # DP-3 is the Kogan Monitor (forced to 2560x1440 due to 2-lane DP bandwidth limits)
    #"DP-3,preferred,auto,1"

    # Test automatic monitor detection
    ",preferred,auto,1"
  ];

  extraSettings = {
    general = {
      gaps_in = 4;
      gaps_out = 4;
    };

    # Workspace rules to place all workspaces 1-10 on DP-3
    workspace = [
      "1, name:1, monitor:DP-3, persistent:true, default:true"
      "2, name:2, monitor:DP-3, persistent:true, default:false"
      "3, name:3, monitor:DP-3, persistent:true, default:false"
      "4, name:4, monitor:DP-3, persistent:true, default:false"
      "5, name:5, monitor:DP-3, persistent:true, default:false"
      "6, name:6, monitor:DP-3, persistent:true, default:false"
      "7, name:7, monitor:DP-3, persistent:true, default:false"
      "8, name:8, monitor:DP-3, persistent:true, default:false"
      "9, name:9, monitor:DP-3, persistent:true, default:false"
      "10, name:10, monitor:DP-3, persistent:true, default:false"
    ];
  };
}
