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
      "1, monitor:desc:HP Inc. HP Z43 CN49500228, default:true"
    ];

  };

}
