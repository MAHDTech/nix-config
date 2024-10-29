{pkgs, ...}: let
  packages = with pkgs; [
    dunst
    nvd
    swww
    waybar
    wlogout
  ];
in {
  home.packages = packages;

  services = {
    # Notification daemon
    # Test with;
    #   notify-send "Test" "This is a test"
    #   dunstify "Test" "This is a test"
    dunst = {
      enable = true;

      catppuccin = {
        enable = true;
        flavor = "mocha";
      };

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

  programs = {
    waybar = {
      enable = true;

      catppuccin = {
        enable = true;
        flavor = "mocha";
        mode = "prependImport";
      };

      systemd = {
        enable = true;
        target = "graphical-session.target";
      };

      # https://github.com/Alexays/Waybar/wiki/Configuration
      settings = [
        {
          layer = "top";
          position = "top";
          height = 30;
          spacing = 5;

          modules-left = [
            "hyprland/workspaces"
          ];

          modules-center = [
            "hyprland/window"

            "cpu"
            "memory"
            "disk"

            "idle_inhibitor"
          ];

          modules-right = [
            "custom/notifications"
            "custom/nixos-check-updates"

            "network"
            "backlight"
            "battery"
            "clock"

            "tray"
            "custom/power"
          ];

          #########################
          # Modules
          #########################

          "hyprland/workspaces" = {
            sort-by-name = true;
            all-outputs = true;

            format = "{name}";
            format-icons = {
              default = " ";
              active = " ";
              urgent = " ";
            };

            disable-scroll = true;
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";

            persistent-workspaces = {
              "Home" = [];
              "2" = [];
              "3" = [];
              "4" = [];
              "5" = [];
              #"6" = [];
              #"7" = [];
              #"8" = [];
              #"9" = [];
              #"0" = [];
            };
          };

          "hyprland/window" = {
            max-length = 100;
            separate-outputs = false;
            rewrite = {
              "" = " 🙈 No Windows? ";
            };
          };

          "cpu" = {
            interval = 5;
            format = " {usage:2}%";
            tooltip = true;
          };

          "memory" = {
            interval = 5;
            format = " {}%";
            tooltip = true;
          };

          "disk" = {
            format = " {free}";
            tooltip = true;
          };

          "idle_inhibitor" = {
            format = "{icon}";
            format-icons = {
              activated = "";
              deactivated = "";
            };
            tooltip = "true";
          };

          "custom/notifications" = {
            tooltip = false;
            format = "{icon} {}";
            format-icons = {
              notification = "<span foreground='red'><sup></sup></span>";
              none = "";
              dnd-notification = "<span foreground='red'><sup></sup></span>";
              dnd-none = "";
              inhibited-notification = "<span foreground='red'><sup></sup></span>";
              inhibited-none = "";
              dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
              dnd-inhibited-none = "";
            };
            return-type = "json";
            exec-if = "which dunstctl";
            exec = "dunstctl history";
            on-click = "sleep 0.1 && dunstctl history";
            escape = true;
          };

          "custom/nixos-check-updates" = {
            exec = "nixos-check-updates";
            on-click = "nixos-check-updates && notify-send 'NixOS updates complete!'";
            interval = 86400;
            tooltip = true;
            return-type = "json";
            format = "{} {icon}";
            format-icons = {
              updates-pending = "";
              up-to-date = "";
            };
          };

          "clock" = {
            timezone = "Australia/Sydney";
            format = "  {:%H:%M}";
            format-alt = "  {:%d/%m/%Y}";
            tooltip = true;
            tooltip-format = "<big>{:%A, %d.%B %Y }</big>\n<tt><small>{calendar}</small></tt>";
          };

          "network" = {
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            format-wifi = "{icon} ({signalStrength}%)  ";
            format-ethernet = "{ifname}: {ipaddr}/{cidr} 󰈀 ";
            format-linked = "{ifname} (No IP) 󰌘 ";
            format-alt = "{ifname}: {ipaddr}/{cidr}";
            format-disc = "Disconnected 󰟦 ";
            format-disconnected = "󰤮";
            tooltip = false;
          };

          "backlight" = {
            device = "intel_backlight";
            format = "{icon}";
            format-icons = ["" "" "" "" "" "" "" "" ""];
          };

          "tray" = {
            icon-size = 21;
            spacing = 14;
          };

          "pulseaudio" = {
            format = "{icon} {volume}% {format_source}";
            format-bluetooth = "{volume}% {icon} {format_source}";
            format-bluetooth-muted = " {icon} {format_source}";
            format-muted = " {format_source}";
            format-source = " {volume}%";
            format-source-muted = "";
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "sleep 0.1 && pavucontrol";
          };

          "custom/exit" = {
            tooltip = false;
            format = "";
            on-click = "sleep 0.1 && wlogout";
          };

          "custom/startmenu" = {
            tooltip = false;
            format = "";
            # exec = "rofi -show drun";
            on-click = "sleep 0.1 && rofi-launcher";
          };

          "custom/hyprbindings" = {
            tooltip = false;
            format = "󱕴";
            on-click = "sleep 0.1 && list-hypr-bindings";
          };

          "custom/lock" = {
            tooltip = false;
            on-click = "${pkgs.hyprlock}/bin/hyprlock";
            format = " ";
          };

          "battery" = {
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{icon} {capacity}%";
            format-alt = "{icon}";
            format-charging = "󰂄 {capacity}%";
            format-plugged = "󱘖 {capacity}%";
            format-icons = [
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
            on-click = "";
            tooltip = false;
          };
        }
      ];

      style = ''
        * {
          font-family: JetBrainsMono Nerd Font Mono;
          font-size: 18px;
          min-height: 0;
        }

        #waybar {
          background: transparent;
          color: @text;
          margin: 5px 5px;
        }

        #workspaces {
          border-radius: 1rem;
          margin: 5px;
          background-color: @surface0;
          margin-left: 1rem;
        }

        #workspaces button {
          color: @lavender;
          border-radius: 1rem;
          padding: 0.4rem;
        }

        #workspaces button.active {
          color: @peach;
          border-radius: 1rem;
        }

        #workspaces button:hover {
          color: @peach;
          border-radius: 1rem;
        }

        #custom-music,
        #tray,
        #backlight,
        #network,
        #clock,
        #battery,
        #custom-lock,
        #custom-notifications,
        #custom-power {
          background-color: @surface0;
          padding: 0.5rem 1rem;
          margin: 5px 0;
        }

        #clock {
          color: @blue;
          border-radius: 0px 1rem 1rem 0px;
          margin-right: 1rem;
        }

        #battery {
          color: @green;
        }

        #battery.charging {
          color: @green;
        }

        #battery.warning:not(.charging) {
          color: @red;
        }

        #backlight {
          color: @yellow;
        }

        #custom-notifications {
          border-radius: 1rem;
          margin-right: 1rem;
          color: @peach;
        }

        #network {
          border-radius: 1rem 0px 0px 1rem;
          color: @sky;
        }

        #custom-music {
          color: @mauve;
          border-radius: 1rem;
        }

        #custom-lock {
            border-radius: 1rem 0px 0px 1rem;
            color: @lavender;
        }

        #custom-power {
            margin-right: 1rem;
            border-radius: 0px 1rem 1rem 0px;
            color: @red;
        }

        #tray {
          margin-right: 1rem;
          border-radius: 1rem;
        }

        @define-color rosewater #f4dbd6;
        @define-color flamingo #f0c6c6;
        @define-color pink #f5bde6;
        @define-color mauve #c6a0f6;
        @define-color red #ed8796;
        @define-color maroon #ee99a0;
        @define-color peach #f5a97f;
        @define-color yellow #eed49f;
        @define-color green #a6da95;
        @define-color teal #8bd5ca;
        @define-color sky #91d7e3;
        @define-color sapphire #7dc4e4;
        @define-color blue #8aadf4;
        @define-color lavender #b7bdf8;
        @define-color text #cad3f5;
        @define-color subtext1 #b8c0e0;
        @define-color subtext0 #a5adcb;
        @define-color overlay2 #939ab7;
        @define-color overlay1 #8087a2;
        @define-color overlay0 #6e738d;
        @define-color surface2 #5b6078;
        @define-color surface1 #494d64;
        @define-color surface0 #363a4f;
        @define-color base #24273a;
        @define-color mantle #1e2030;
        @define-color crust #181926;
      '';
    };
  };
}
