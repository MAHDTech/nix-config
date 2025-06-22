##################################################
# JONS desktop monitor configuration
##################################################

# NOTES:
# - This desktop has a single display
# - 40" HP
# - Use hyprland automatic detection

{
  monitorConfig = [
    # Let Hyprland automatically detect and configure the monitor
    #",preferred,auto,1"

    # HP 40"
    "desc:HP Inc. HP Z43 CN49500228,3840x2160@59.99700,0x0,1.6,bitdepth,10"
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
    ];

  };

}
