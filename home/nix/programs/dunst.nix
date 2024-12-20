{
  services = {
    # Notification daemon
    # Test with;
    #   notify-send "Test" "This is a test"
    #   dunstify "Test" "This is a test"
    dunst = {
      enable = true;

      settings = {
        global = {
          width = 300;
          height = 300;
          offset = "30x50";
          origin = "top-right";
          transparency = 10;
          frame_color = "#eceff1";
          font = "JetBrainsMono Nerd Font Mono 18";
        };
        urgency_normal = {
          background = "#37474f";
          foreground = "#eceff1";
          timeout = 10;
        };
      };
    };
  };
}
