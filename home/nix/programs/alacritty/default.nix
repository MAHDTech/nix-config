{ lib, ... }:
{
  imports = [
    ./themes
  ];

  programs.alacritty = {
    enable = true;

    settings = {
      general = {
        live_config_reload = true;
      };

      window = {
        # mkForce overrides Stylix's default 1.0 terminal opacity
        opacity = lib.mkForce 0.95;

        dimensions = {
          columns = 120;
          lines = 35;
        };

        padding = {
          x = 8;
          y = 6;
        };

        dynamic_padding = true;
        decorations = "Full";
        startup_mode = "Windowed";
        dynamic_title = true;
      };

      scrolling = {
        history = 10000;
        multiplier = 3;
      };

      font = {
        builtin_box_drawing = true;
      };

      cursor = {
        style = {
          shape = "Beam";
          blinking = "On";
        };
        unfocused_hollow = true;
        thickness = 0.15;
      };

      selection = {
        semantic_escape_chars = ",│`|:\"' ()[]{}<>\t";
        save_to_clipboard = true;
      };

      mouse = {
        hide_when_typing = true;
      };

      bell = {
        animation = "EaseOutExpo";
        duration = 150;
      };

      # Interactive URL & Link Hints
      hints.enabled = [
        {
          regex = ''(ipfs:|ipns:|magnet:|mailto:|gemini://|gopher://|https://|http://|news:|file:|git://|ssh://|ftp://)[^\u0000-\u001f\u007f-\u009f<>"\\s{-}\\^⟨⟩`]+'';
          hyperlinks = true;
          command = "xdg-open";
          post_processing = true;
          mouse = {
            enabled = true;
            mods = "None";
          };
          binding = {
            key = "U";
            mods = "Control|Shift";
            mode = "~Vi";
          };
        }
      ];

      # Power-user keybindings
      keyboard.bindings = [
        # Vi Mode navigation (h/j/k/l, v/y to select/copy)
        {
          key = "Space";
          mods = "Control|Shift";
          action = "ToggleViMode";
        }
        # Interactive regex scrollback search
        {
          key = "F";
          mods = "Control|Shift";
          action = "SearchForward";
          mode = "~Search";
        }
        # Spawn new window in same directory
        {
          key = "N";
          mods = "Control|Shift";
          action = "CreateNewWindow";
        }
        # Font size zoom controls
        {
          key = "Plus";
          mods = "Control";
          action = "IncreaseFontSize";
        }
        {
          key = "Equals";
          mods = "Control";
          action = "IncreaseFontSize";
        }
        {
          key = "Minus";
          mods = "Control";
          action = "DecreaseFontSize";
        }
        {
          key = "Key0";
          mods = "Control";
          action = "ResetFontSize";
        }
        # Standard clipboard
        {
          key = "V";
          mods = "Control|Shift";
          action = "Paste";
        }
        {
          key = "C";
          mods = "Control|Shift";
          action = "Copy";
        }
        # OS Window Fullscreen
        {
          key = "F11";
          action = "ToggleFullscreen";
        }
      ];
    };
  };
}
