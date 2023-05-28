{pkgs, ...}: {
  programs.alacritty = {
    enable = true;

    package = pkgs.alacritty;

    settings = {
      env = {
        TERM = "alacritty";
      };

      window = {
        dimensions = {
          columns = 100;
          lines = 50;
        };

        position = {
          x = 0;
          y = 0;
        };

        padding = {
          x = 0;
          y = 0;
        };

        opacity = 1.0;

        dynamic_padding = true;

        decorations = "full";
        decorations_theme_variant = "Dark";

        startup_mode = "Windowed";

        dynamic_title = true;

        class = {
          instance = "Alacritty";
          general = "Alacritty";
        };
      };

      scrolling = {
        history = 10000;

        multiplier = 3;
      };

      font = {
        normal = {
          family = "Ubuntu Mono";
          style = "Regular";
        };

        bold = {
          family = "Ubuntu Mono";
          style = "Bold";
        };

        italic = {
          family = "Ubuntu Mono";
          style = "Italic";
        };

        bold_italic = {
          family = "Ubuntu Mono";
          style = "Bold Italic";
        };

        size = 16.0;

        offset = {
          x = 0;
          y = 0;
        };

        glyph_offset = {
          x = 0;
          y = 0;
        };
      };

      draw_bold_text_with_bright_colors = true;

      # https://github.com/alacritty/alacritty-theme
      colors = {
        primary = {
          background = "0x24283b";
          foreground = "0xa9b1d6";
        };

        cursor = {
          text = "0x7f85a3";
          cursor = "0x808080";
        };

        normal = {
          black = "0x32344a";
          red = "0xf7768e";
          green = "0x9ece6a";
          yellow = "0xe0af68";
          blue = "0x7aa2f7";
          magenta = "0xad8ee6";
          cyan = "0x449dab";
          white = "0x9699a8";
        };

        bright = {
          black = "0x444b6a";
          red = "0xff7a93";
          green = "0xb9f27c";
          yellow = "0xff9e64";
          blue = "0x7da6ff";
          magenta = "0xbb9af7";
          cyan = "0x0db9d7";
          white = "0xacb0d0";
        };
      };

      schemes = {
        tokyo-night-storm = {
          primary = {
            background = "0x24283b";
            foreground = "0xa9b1d6";
          };

          cursor = {
            text = "0x7f85a3";
            cursor = "0x808080";
          };

          normal = {
            black = "0x32344a";
            red = "0xf7768e";
            green = "0x9ece6a";
            yellow = "0xe0af68";
            blue = "0x7aa2f7";
            magenta = "0xad8ee6";
            cyan = "0x449dab";
            white = "0x9699a8";
          };

          bright = {
            black = "0x444b6a";
            red = "0xff7a93";
            green = "0xb9f27c";
            yellow = "0xff9e64";
            blue = "0x7da6ff";
            magenta = "0xbb9af7";
            cyan = "0x0db9d7";
            white = "0xacb0d0";
          };
        };

        moonlight = {
          primary = {
            background = "0x1e2030";
            foreground = "0x7f85a3";
          };

          cursor = {
            text = "0x7f85a3";
            cursor = "0x808080";
          };

          normal = {
            black = "0x444a73";
            red = "0xff5370";
            green = "0x4fd6be";
            yellow = "0xffc777";
            blue = "0x3e68d7";
            magenta = "0xfc7b7b";
            cyan = "0x86e1fc";
            white = "0xd0d0d0";
          };

          bright = {
            black = "0x828bb8";
            red = "0xff98a4";
            green = "0xc3e88d";
            yellow = "0xffc777";
            blue = "0x82aaff";
            magenta = "0xff966c";
            cyan = "0xb4f9f8";
            white = "0x5f8787";
          };
        };
      };

      bell = {
        animation = "EaseOutExpo";
        duration = 250;

        color = "#ffffff";
      };

      selection = {
        semantic_escape_chars = ",│`|:\"' ()[]{}<>\t";

        save_to_clipboard = true;
      };

      cursor = {
        style = "Block";

        vi_mode_style = "None";

        unfocused_hollow = true;

        thickness = 0.15;
      };

      live_config_reload = true;

      mouse = {
        hide_when_typing = false;

        double_click = {
          threshold = 300;
        };
        triple_click = {
          threshold = 300;
        };
      };

      debug = {
        persistent_logging = false;

        log_level = "Info";
      };
    };
  };
}
