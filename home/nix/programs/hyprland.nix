{pkgs, ...}: let
  ##################################################
  # If COSMIC and Hyprland had a baby...
  ##################################################
  packages = with pkgs; [
    # Text editor
    cosmic-edit

    # Flatpak store
    cosmic-store

    # Icons
    cosmic-icons

    # File browser
    cosmic-files

    # Terminal
    cosmic-term

    # Launcher
    cosmic-launcher
    pop-launcher
  ];
in {
  home.packages = packages;

  programs = {
    # Lock screen utility.
    hyprlock = {
      enable = true;
      # https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/
      settings = {
        general = {
          # Disable the loading bar at the botton of the screen.
          disable_loading_bar = false;
          # The amount of time in seconds of idle until lock activates.
          grace = 300;
          # Hide the cursor
          hide_cursor = true;
          # Disable fade in animation
          no_fade_in = false;
          # Disable fade out animation
          no_fade_out = false;
          # Use fractional scaling, 0=disabled, 1=enabled, 2=auto
          fractional_scaling = 2;
          # Enable fingerprint auth with fprintd
          enable_fingerprint = false;
          # Fingerprint message
          fingerprint_present_message = "Scanning fingerprint...";
        };
        # Appearance.
        background = [
          {
            path = "screenshot";
            blur_passes = 3;
            blur_size = 8;
          }
        ];
        input-field = [
          {
            size = "200, 50";
            position = "0, -80";
            halign = "center";
            valisng = "center";
            monitor = "";
            dots_center = true;
            fade_on_empty = false;
            font_color = "rgb(202, 211, 245)";
            inner_color = "rgb(91, 96, 120)";
            outer_color = "rgb(24, 25, 38)";
            outline_thickness = 5;
            placeholder_text = "Password...";
            shadow_passes = 2;
          }
        ];
      };
    };
  };

  services = {
    # Idle daemon
    hypridle = {
      enable = true;
      # List of prefix of attributes to source at the top of the config.
      importantPrefixes = [
        "$"
      ];
      # https://wiki.hyprland.org/Hypr-Ecosystem/hypridle/
      settings = {
        general = {
          # Command to run when receiving a lock event.
          lock_cmd = "pidof hyprlock || hyprlock";
          # Command to run when preparing to sleep.
          after_sleep_cmd = "hyprctl dispatch dpms on";
          # Whether to ignore dbus-sent idle inhibit events.
          ignore_dbus_inhibit = false;
          # Whether to ignore systemd-inhibit inhibitors
          ignore_systemd_inhibit = false;
        };
        listener = [
          {
            # How long to wait unti activation of lockscreen.
            timeout = 300;
            on-timeout = "pidof hyprlock || hyprlock";
          }
          {
            # How long to wait until activation of monitor sleep.
            timeout = 900;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };

    # Wallpaper daemon
    hyprpaper = {
      enable = true;
      # https://wiki.hyprland.org/Hypr-Ecosystem/hyprpaper/
      # List of prefix of attributes to source at the top of the config.
      importantPrefixes = [
        "$"
      ];
      settings = {
        # Whether to enable IPC
        ipc = true;
        # Whether to enable splash over the wallpaper
        splash = true;
        # How far in % of height to display the splash
        splash_offset = 2.0;
        # Images to preload into memory.
        #preload = [
        #  "/share/wallpapers/buttons.png"
        #  "/share/wallpapers/cat_pacman.png"
        #];
        # Wallpapers to display on which monitor.
        # run hyprctl monitors to see ID.
        #wallpaper = [
        #  "DP-3,/share/wallpapers/buttons.png"
        #  "DP-1,/share/wallpapers/cat_pacman.png"
        #];
      };
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd = {
      # Whether to enable systemd unit link to graphical-session.target
      enable = true;
      # Whether to enable autostart of applications using systemd-xdg-autostart-generator.
      enableXdgAutostart = true;
      # List of extra commands to run after D-Bus activation
      extraCommands = [
        "systemctl --user stop hyprland-session.target"
        "systemctl --user start hyprland-session.target"
      ];

      # Environment variables that get imported into systemd and D-Bud user env.
      variables = [
        # "--all"
        "DISPLAY"
        "HYPRLAND_INSTANCE_SIGNATURE"
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP"
      ];
    };

    # Whether to enable XWayland for legacy X11 application compatibility.
    xwayland = {
      enable = true;
    };

    # Whether to enable putting source entries at the top of the config.
    sourceFirst = true;

    # List of prefix of attributes to source at the top of the config.
    importantPrefixes = [
      "$"
      "bezier"
      "name"
      "source"
    ];

    plugins = [];

    settings = {
      # Remove the generated warning bar.
      autogenerated = 0;

      ################
      ### MONITORS ###
      ################

      # https://wiki.hyprland.org/Configuring/Monitors/

      monitor = [
        # Laptop
        #"desc:BOE 0x084D, preferred, auto, auto"
        "desc:BOE 0x084D, highres, auto, 2"

        # Kogan
        #"desc:KOGAN AUSTRALIA PTY LTD KAMN49QDQUCLA 0000000000000, preferred, auto, auto"
        "desc:KOGAN AUSTRALIA PTY LTD KAMN49QDQUCLA 0000000000000, highres, auto, 2"

        # Alienware
        # "desc:XXX, preferred, auto, auto";
      ];

      #############################
      ### ENVIRONMENT VARIABLES ###
      #############################

      # See https://wiki.hyprland.org/Configuring/Environment-variables/

      env = [
        "GDK_SCALE=2"
        "XCURSOR_SIZE,48"
        "HYPRCURSOR_SIZE,48"
      ];

      ###################
      ### XWayland ###
      ###################

      xwayland = {
        force_zero_scaling = true;
      };

      ###################
      ### PROGRAMS ###
      ###################

      # https://wiki.hyprland.org/Configuring/Keywords/

      "$terminal" = "cosmic-term";

      "$fileManager" = "cosmic-files";

      #"$menu" = "rofi --show drun";
      "$menu" = "cosmic-launcher";

      "$switcher" = "rofi window";
    };

    # TODO: Don't be lazy and move to settings...
    extraConfig = ''
      ###################
      ### extraConfig ###
      ###################

      #################
      ### AUTOSTART ###
      #################

      # Autostart necessary processes (like notifications daemons, status bars, etc.)
      # Or execute your favorite apps at launch like this:

      # exec-once = $terminal
      # exec-once = nm-applet &
      # exec-once = waybar & hyprpaper & firefox

      #####################
      ### LOOK AND FEEL ###
      #####################

      # Refer to https://wiki.hyprland.org/Configuring/Variables/

      # https://wiki.hyprland.org/Configuring/Variables/#general
      general {
          gaps_in = 5
          gaps_out = 20

          border_size = 2

          # https://wiki.hyprland.org/Configuring/Variables/#variable-types for info about colors
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)

          # Set to true enable resizing windows by clicking and dragging on borders and gaps
          resize_on_border = false

          # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
          allow_tearing = false

          layout = dwindle
      }

      # https://wiki.hyprland.org/Configuring/Variables/#decoration
      decoration {
          rounding = 10

          # Change transparency of focused and unfocused windows
          active_opacity = 1.0
          inactive_opacity = 1.0

          drop_shadow = true
          shadow_range = 4
          shadow_render_power = 3
          col.shadow = rgba(1a1a1aee)

          # https://wiki.hyprland.org/Configuring/Variables/#blur
          blur {
              enabled = true
              size = 3
              passes = 1

              vibrancy = 0.1696
          }
      }

      # https://wiki.hyprland.org/Configuring/Variables/#animations
      animations {
          enabled = true

          # Default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

          bezier = myBezier, 0.05, 0.9, 0.1, 1.05

          animation = windows, 1, 7, myBezier
          animation = windowsOut, 1, 7, default, popin 80%
          animation = border, 1, 10, default
          animation = borderangle, 1, 8, default
          animation = fade, 1, 7, default
          animation = workspaces, 1, 6, default
      }

      # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
      dwindle {
          pseudotile = true # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
          preserve_split = true # You probably want this
      }

      # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
      master {
          new_status = master
      }

      # https://wiki.hyprland.org/Configuring/Variables/#misc
      misc {
          force_default_wallpaper = -1 # Set to 0 or 1 to disable the anime mascot wallpapers
          disable_hyprland_logo = false # If true disables the random hyprland logo / anime girl background. :(
      }

      #############
      ### INPUT ###
      #############

      # https://wiki.hyprland.org/Configuring/Variables/#input
      input {
          kb_layout = us
          kb_variant =
          kb_model =
          kb_options =
          kb_rules =

          follow_mouse = 1

          sensitivity = 0 # -1.0 - 1.0, 0 means no modification.

          touchpad {
              natural_scroll = false
          }
      }

      # https://wiki.hyprland.org/Configuring/Variables/#gestures
      gestures {
          workspace_swipe = false
      }

      # Example per-device config
      # See https://wiki.hyprland.org/Configuring/Keywords/#per-device-input-configs for more
      device {
          name = epic-mouse-v1
          sensitivity = -0.5
      }


      ###################
      ### KEYBINDINGS ###
      ###################

      # See https://wiki.hyprland.org/Configuring/Keywords/
      $mainMod = SUPER # Sets "Windows" key as main modifier

      # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
      bind = $mainMod, Q, exec, $terminal
      bind = $mainMod, C, killactive,
      bind = $mainMod, M, exit,
      bind = $mainMod, E, exec, $fileManager
      bind = $mainMod, V, togglefloating,
      bind = $mainMod, R, exec, $menu
      bind = $mainMod, P, pseudo, # dwindle
      bind = $mainMod, J, togglesplit, # dwindle

      # Move focus with mainMod + arrow keys
      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d

      # Switch workspaces with mainMod + [0-9]
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      # Example special workspace (scratchpad)
      bind = $mainMod, S, togglespecialworkspace, magic
      bind = $mainMod SHIFT, S, movetoworkspace, special:magic

      # Scroll through existing workspaces with mainMod + scroll
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      # Laptop multimedia keys for volume and LCD brightness
      bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      bindel = ,XF86MonBrightnessUp, exec, brightnessctl s 10%+
      bindel = ,XF86MonBrightnessDown, exec, brightnessctl s 10%-

      # Requires playerctl
      bindl = , XF86AudioNext, exec, playerctl next
      bindl = , XF86AudioPause, exec, playerctl play-pause
      bindl = , XF86AudioPlay, exec, playerctl play-pause
      bindl = , XF86AudioPrev, exec, playerctl previous

      ##############################
      ### WINDOWS AND WORKSPACES ###
      ##############################

      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      # See https://wiki.hyprland.org/Configuring/Workspace-Rules/ for workspace rules

      # Example windowrule v1
      # windowrule = float, ^(kitty)$

      # Example windowrule v2
      # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$

      # Ignore maximize requests from apps. You'll probably like this.
      windowrulev2 = suppressevent maximize, class:.*

      # Fix some dragging issues with XWayland
      windowrulev2 = nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0
    '';
  };
}
