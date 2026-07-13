{
  # Active wallpaper preferences from ~/.config/cosmic/com.system76.CosmicBackground/v1/
  # By default, same_on_all is true, which maps to the "all" output.
  #
  # Example configuration for multiple outputs:
  # wayland.desktopManager.cosmic.wallpapers = [
  #   {
  #     output = "HDMI-A-5";
  #     source = {
  #       __type = "enum";
  #       variant = "Path";
  #       value = [ "/etc/profiles/per-user/mahdtech/share/backgrounds" ];
  #     };
  #     filter_by_theme = false;
  #     rotation_frequency = 300;
  #     filter_method = {
  #       __type = "enum";
  #       variant = "Lanczos";
  #     };
  #     scaling_mode = {
  #       __type = "enum";
  #       variant = "Zoom";
  #     };
  #     sampling_method = {
  #       __type = "enum";
  #       variant = "Alphanumeric";
  #     };
  #   }
  # ];

  wayland.desktopManager.cosmic.wallpapers = [
    {
      output = "all";
      source = {
        __type = "enum";
        variant = "Path";
        value = [ "/home/mahdtech/Sync/Pictures/Wallpapers" ];
      };
      filter_by_theme = true;
      rotation_frequency = 300;
      filter_method = {
        __type = "enum";
        variant = "Lanczos";
      };
      scaling_mode = {
        __type = "enum";
        variant = "Zoom";
      };
      sampling_method = {
        __type = "enum";
        variant = "Alphanumeric";
      };
    }
  ];
}
