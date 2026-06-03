##################################################
# ORION host monitor configuration
##################################################

{
  monitorConfig = [
    # Unknown-1 is the Kogan Monitor
    "Unknown-1,1920x1080@60,0x0,1"
  ];

  extraSettings = {
    general = {
      gaps_in = 4;
      gaps_out = 4;
    };

    # Workspace rules to place all workspaces 1-10 on Unknown-1
    workspace = [
      "1, name:1, monitor:Unknown-1, persistent:true, default:true"
      "2, name:2, monitor:Unknown-1, persistent:true, default:false"
      "3, name:3, monitor:Unknown-1, persistent:true, default:false"
      "4, name:4, monitor:Unknown-1, persistent:true, default:false"
      "5, name:5, monitor:Unknown-1, persistent:true, default:false"
      "6, name:6, monitor:Unknown-1, persistent:true, default:false"
      "7, name:7, monitor:Unknown-1, persistent:true, default:false"
      "8, name:8, monitor:Unknown-1, persistent:true, default:false"
      "9, name:9, monitor:Unknown-1, persistent:true, default:false"
      "10, name:10, monitor:Unknown-1, persistent:true, default:false"
    ];
  };
}
