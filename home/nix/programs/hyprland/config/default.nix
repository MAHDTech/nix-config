##################################################
# Default monitor configuration
##################################################

# NOTES:
# - This is the default when no hostname is matched
# - Use hyprland automatic detection for maximum compatibility

{
  monitorConfig = [
    # Automatic monitor detection with reasonable defaults
    ",preferred,auto,1.6"
  ];

  extraSettings = {
    # Conservative defaults for unknown systems
    general = {
      gaps_in = 4;
      gaps_out = 4;
    };
  };
}
