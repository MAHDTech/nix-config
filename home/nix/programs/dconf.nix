{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };

    "org/gnome/mutter" = {
      check-alive-timeout = 10000;
      experimental-features = [
        "scale-monitor-framebuffer"
      ];
    };
  };
}
