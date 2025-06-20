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
    ",preferred,auto,1"
  ];

  extraSettings = {
    # Desktop settings - can use standard gaps for large screen
    general = {
      gaps_in = 4;
      gaps_out = 4;
    };
  };
}
