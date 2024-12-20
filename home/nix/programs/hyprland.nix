{pkgs, ...}: let
  packages = with pkgs; [
    brightnessctl
    cosmic-edit
    cosmic-files
    cosmic-icons
    cosmic-launcher
    cosmic-store
    cosmic-term
    grim
    hyprpicker
    hyprshot
    jq
    libnotify
    lz4
    nvd
    pavucontrol
    pop-launcher
    slurp
    swappy
    swww
    wayland-pipewire-idle-inhibit
    wayshot
    #wf-recorder
    wl-clipboard
    #wl-screenrec
    wlogout
  ];
in {
  home.packages = packages;

  programs = {
    hyprlock = {
      enable = true;

      # https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/
      settings = {
        #########################
        # Hyprlock General
        #########################

        general = {
          # Disable the loading bar at the bottom of the screen.
          disable_loading_bar = false;
          # Hide the cursor
          hide_cursor = true;
          # The amount of time in seconds of idle until lock activates.
          grace = 300;
          # Disable fade in animation
          no_fade_in = false;
          # Disable fade out animation
          no_fade_out = false;
          # Skip validation when no password is provided.
          ignore_empty_input = false;
          # Immediately draw widgets
          immediate_render = false;
          # PAM module used for authentication
          pam_module = "hyprlock";
          # Enable to trim text
          text_trim = true;
          # Use fractional scaling, 0=disabled, 1=enabled, 2=auto
          fractional_scaling = 2;
          # Enable fingerprint auth with fprintd
          enable_fingerprint = false;
          # Fingerprint message
          fingerprint_present_message = "Scanning fingerprint...";
        };

        #########################
        # Hyprlock Background
        #########################

        background = [
          {
            path = "screenshot";
            blur_passes = 3;
            blur_size = 8;
          }
        ];

        #########################
        # Hyprlock Input Field
        #########################

        input-field = [
          {
            size = "200, 50";
            position = "0, -80";
            halign = "center";
            valign = "center";
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
    hypridle = {
      enable = true;

      importantPrefixes = [
        "$"
      ];

      # https://wiki.hyprland.org/Hypr-Ecosystem/hypridle/
      settings = {
        #########################
        # Hypridle General
        #########################

        general = {
          # Lock command
          lock_cmd = "pidof hyprlock || hyprlock";
          # Unlock command
          #unlock_cmd = "";

          # Before sleep command
          before_sleep_cmd = "loginctl lock-session";
          # Preparing to sleep command
          after_sleep_cmd = "hyprctl dispatch dpms on";

          # Whether to ignore dbus-sent idle inhibit events.
          ignore_dbus_inhibit = false;
          # Whether to ignore systemd-inhibit inhibitors
          ignore_systemd_inhibit = false;
        };

        #########################
        # Hypridle Listeners
        #########################

        listener = [
          {
            # How long to wait until activation of lockscreen.
            timeout = 300;
            on-timeout = "notify-send 'Locking screen...' ; pidof hyprlock || hyprlock";
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

    hyprpaper = {
      enable = true;

      importantPrefixes = [
        "$"
      ];

      # https://wiki.hyprland.org/Hypr-Ecosystem/hyprpaper/

      settings = {
        #########################
        # Hyprpaper General
        #########################

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
      enable = true;

      enableXdgAutostart = true;

      extraCommands = [
        "systemctl --user stop hyprland-session.target"
        "systemctl --user start hyprland-session.target"
      ];

      variables = [
        # "--all"
        "DISPLAY"
        "HYPRLAND_INSTANCE_SIGNATURE"
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP"
      ];
    };

    # Check if a client is using XWayland with 'hyprctl clients'
    xwayland = {
      enable = true;
    };

    sourceFirst = true;

    importantPrefixes = [
      "$"
      "bezier"
      "name"
      "source"
    ];

    plugins = [];

    settings = {
      autogenerated = 0;
      ################
      # Shortcut Variables
      ################

      "$lock" = "hyprlock";
      "$screenshot" = "hyprshot --mode region";

      ################
      # Hyprland Monitors
      ################

      # Monitor names
      "$screen1" = "BOE 0x084D";
      "$screen2" = "KOGAN AUSTRALIA PTY LTD KAMN49QDQUCLA 0000000000000";
      "$screen3" = "Dell Inc. Dell AW3423DW ##GrMYMxgwABgH";

      # https://wiki.hyprland.org/Configuring/Monitors/
      monitor = [
        # Key
        # name, resolution, position, scale

        # Laptop Monitor.
        #"desc:$screen1,1920x1080@144,0x0,1,bitdepth,10"
        "desc:$screen1,1920x1080@144,0x0,1.6,bitdepth,10"

        # Kogan Monitor underneath Laptop Monitor.
        #"desc:$screen2,5120x1440@60,720x1080,1,bitdepth,10"
        "desc:$screen2,5120x1440@60,450x675,1.6,bitdepth,10"

        # Alienware Monitor to the right of Laptop Monitor.
        #"desc:$screen3,3440x1440@60,1920x0,1,bitdepth,10"
        # Raise the Alienware Monitor up just a bit to compensate for the
        # smaller resolution of the Laptop Monitor.
        # 1080 - 1440 = 360
        # 360 / 1.6 = 225
        "desc:$screen3,3440x1440@60,1200x-225,1.6,bitdepth,10"
      ];

      #########################
      # Hyprland General
      #########################

      # https://wiki.hyprland.org/Configuring/Variables

      general = {
        # The size of the border around windows
        border_size = 2;
        # Disable border on floating windows
        no_border_on_floating = false;
        # Gaps between windows and other windows
        gaps_in = 4;
        # Gaps between windows and border
        gaps_out = 4;
        # Gaps between workspaces
        gaps_workspaces = 0;
        # Border colour for inactive windows.
        "col.inactive_border" = "rgba(595959aa)";
        # Border colour for active windows.
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        # Inactive border colour for windows that cannot be grouped.
        "col.nogroup_border" = "0xffffaaff";
        # Active border colour for windows that cannot be grouped.
        "col.nogroup_border_active" = "0xffff00ff";
        # Layout to use (dwindle or master)
        layout = "dwindle";
        # If enabled, will not fall back to next available window
        # when moving focus in a direction where a window was not found
        no_focus_fallback = false;
        # Enables resizing by clicking and dragging borders and gaps
        resize_on_border = true;
        # Extend the grab area for borders and gaps
        extend_border_grab_area = 15;
        # Master switch for allowing tearing.
        allow_tearing = false;
        # Force floating windows to use a specific corner for resisizing
        # (1-4 going clockwise or 0 to disable for all windows)
        resize_corner = 0;

        #########################
        # Snap
        #########################

        # TODO: Enable in v0.45+

        #snap = {
        # Enable snapping for floating windows
        #  enabled = true;
        # Minimum gap in pixels between windows for snapping
        #  window_gap = 10;
        # Minimum gap in pixels between windows and edge before snapping
        #  monitor_gap = 10;
        # if true, windows snap such that only one border’s worth of space is between them.
        #  border_overlap = false;
        #};
      };

      #########################
      # Hyprland Decoration
      #########################

      # https://wiki.hyprland.org/Configuring/Variables/#decoration

      decoration = {
        # Rounded corners' radius
        rounding = 10;
        # Opacity of active windows (0.0 - 1.0)
        active_opacity = 1.0;
        # Opacity of inactive windows (0.0 - 1.0)
        inactive_opacity = 0.8;
        # Opacity of fullscreen windows (0.0 - 1.0)
        fullscreen_opacity = 0.9;
        # Enable dimming of inactive windows
        dim_inactive = true;
        # How much to dim inactive windows
        dim_strength = 0.5;
        # How much to dim the rest of the screen
        dim_special = 0.2;
        # How much the dimaround window rule should dim by.
        dim_around = 0.4;

        #########################
        # Hyprland Decoration Blur
        #########################

        # https://wiki.hyprland.org/Configuring/Variables/#blur

        blur = {
          # Enable blur
          enabled = true;
          # The blur distance
          size = 14;
          # The number of blur passes
          passes = 4;
          # Make the blue later ignore the opacity of windows
          ignore_opacity = false;
          # Whether to use the new optimizations
          new_optimizations = true;
          # If enabled, floating windows will ignore tiled windows.
          xray = true;
          # How much noise to apply
          noise = 0.0117;
          # How much contract modulation
          contrast = 1;
          # How much brightness modulation
          brightness = 1;
          # Increase saturation
          vibrancy = 0.1696;
          # How strong the vibrancy effect is
          vibrancy_darkness = 0.1;
          # Whether to blue special workspace
          special = false;
          # Whether to blur popups and right-click menus
          popups = false;
          # How much to blur popups and right-click menus
          popups_ignorealpha = 0.2;
        };

        #########################
        # Hyprland Shadow
        #########################

        # https://wiki.hyprland.org/Configuring/Variables/#shadow

        shadow = {
          # Whether to enable shadows
          enabled = true;
          # Shadow range size in px
          range = 5;
          # In what power to render the falloff (more power, the faster the falloff)
          render_power = 3;
          # if enabled, will make the shadows sharp, akin to an infinite render power
          sharp = false;
          # if true, the shadow will not be rendered behind the window itself, only around it.
          ignore_window = true;
          # shadow’s color. Alpha dictates shadow’s opacity.
          color = "rgba(1a1a1aee)";
          # inactive shadow color. (if not set, will fall back to color)
          color_inactive = "rgba(1a1a1aee)";
          # shadow’s rendering offset.
          #offset = "[0, 0]";
          # shadow’s scale. [0.0 - 1.0]
          scale = 1.0;
        };
      };

      #############################
      # Hyprland Animations
      #############################

      # https://wiki.hyprland.org/Configuring/Variables/#animations

      animations = {
        # Whether to enable animations
        enabled = true;
        # Enable first launch animation
        first_launch_animation = true;

        # Bezier curve for animations
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

        animation = [
          # Animation for windows
          "windows, 1, 7, myBezier"
          # Animation for windows out
          "windowsOut, 1, 7, default, popin 80%"
          # Animation for border
          "border, 1, 10, default"
          # Animation for border angle
          "borderangle, 1, 8, default"
          # Animation for fade
          "fade, 1, 7, default"
          # Animation for workspaces
          "workspaces, 1, 6, default"
        ];
      };

      #############################
      # Hyprland Input
      #############################

      # https://wiki.hyprland.org/Configuring/Variables/#input

      input = {
        #########################
        # Hyprland Input Keyboard
        #########################

        # Appropriate XKB keymap parameter.
        kb_model = "";
        # Appropriate XKB layout parameter.
        kb_layout = "us";
        # Appropriate XKB variant parameter.
        kb_variant = "";
        # Appropriate XKB options parameter.
        kb_options = "";
        # Appropriate XKB rules parameter.
        kb_rules = "";
        # Engage numlock by default
        numlock_by_default = false;
        # Determines how keybinds act when multiple layouts are used.
        # if false, keybinds always act as if the first layout is active.
        # if true, keybinds act as if the last layout is active.
        resolve_binds_by_sym = false;
        # The keyboard repeat rate.
        repeat_rate = 25;
        # The keyboard repeat delay.
        repeat_delay = 600;

        #########################
        # Hyprland Input Mouse
        #########################

        # Mouse sensitivity
        sensitivity = 0.0;
        # Sets the cursor acceleration profile.
        # Can be "flat", "adaptive", or empty for default.
        accel_profile = "flat";
        # Force no mouse acceleration
        force_no_accel = false;
        # Left hand mouse
        left_handed = false;
        # Sets the scroll method
        # Can be "2fg", "edge", "on_button_down", "no_scroll"
        #scroll_method = "2fg";
        # Sets the scroll button
        scroll_button = 0;
        # If enabled, the scroll button does not need to be held down.
        scroll_button_lock = false;
        # Multiplier added to scroll movement for external mice.
        scroll_factor = 1.0;
        # Inverts natural scrolling
        natural_scroll = false;
        # Cursor movement affect window focus
        # 0 Cursor movement will not change focus
        # 1 Cursor movement will always change focus to under the cursor
        # 2 Cursor focus will be detached from keyboard focus. Need to click to change focus.
        # 3 Custor focus will be completely separate from keyboard focus. Clicking a windoe will not change focus.
        follow_mouse = 1;
        # Window focus when a window is closes
        # 0 = shift to next window
        # 1 = shift to window under cursor
        focus_on_close = 0;
        # If disabled, mouse focus won't switch to the hovered window.
        mouse_refocus = true;
        # If enabled, focus will change to the window under the cursor when changing
        # from tiles to floating.
        float_switch_override_focus = 1;
        # If enabled, having only one floating windows in the special workspace
        # will not block focusing windows in the regular workspace.
        special_fallthrough = false;
        # Handles axis events
        # 1 sends out of bound coordinates
        # 2 fake pointer coordinates
        # 3 Warps the cursor to the closest point inside the window
        off_window_axis_events = 1;
        # Emulates discrete scrolling from high resolution.
        # 0 disables
        # 1 enable handling non-standard events only
        # 2 force enables all scroll wheel events
        emulate_discrete_scroll = 1;

        #########################
        # Hyprland Input Touchpad
        #########################

        touchpad = {
          # Disable the touchpad when typing
          disable_while_typing = true;
          # Inverts scrolling direction.
          natural_scroll = false;
          # Multiplier applied to the amount of scroll movement.
          scroll_factor = 1.0;
          # Sending LMB and RMB simultaneously will be interpreted as middle click.
          middle_button_emulation = false;
          # Tap mapping for touchpad button.
          # "lrm" = left, right, middle
          # "lmr" = left, middle, right
          tap_button_map = "lrm";
          # Clickfinger behavior with button presses.
          # Button fingers with 1, 2, 3 will be mapped to
          # LMB, RMB, MMB
          clickfinger_behavior = false;
          # Tapping on the touchpad with 1,2,3 fingers will send
          # LMB, RMB, MMB respectively.
          "tap-to-click" = true;
          # When enabled, lifting the finger off for a short time
          # when dragging will not drop the dragged item.
          drag_lock = false;
          # Enable tap and drag mode.
          "tap-and-drag" = true;
        };

        #########################
        # Hyprland Input Touchdevice
        #########################

        touchdevice = {
          # Whether touch screen is enabled.
          enabled = true;
          # Transform the input from touch devices.
          transform = 0;
          # The monitor to bind touch devices. (default is auto)
          #output = "[[Auto]]";
        };
      };

      #########################
      # Hyprland Misc
      #########################

      # https://wiki.hyprland.org/Configuring/Variables/#misc

      misc = {
        # Disable the random hyprland logo / anime girl.
        disable_hyprland_logo = true;
        # Disable the Hyprland splash rendering.
        disable_splash_rendering = true;
        # Change the colour of the splash text
        "col.splash" = "0xffffff";
        # Set the default font
        font_family = "Sans";
        # Changes the font used to render the splash
        #splash_font_family = "";
        # Force default wallpaper.
        # 0 = disable
        # 1 = enable
        # -1 = random
        force_default_wallpaper = -1;
        # Controls the VFR status of Hyprland.
        vfr = true;
        # Control the VRR status of monitors
        # 0 = off
        # 1 = on
        # 2 = fullscreen only
        vrr = 0;
        # If DPMS is off, wake up monitor when mouse moves.
        mouse_move_enables_dpms = true;
        # If DPMS is off, wake up monitor when a key is pressed.
        key_press_enables_dpms = true;
        # Will make mouse focus follow the mouse.
        always_follow_on_dnd = true;
        # If true will make keyboard-interactive layers keep their focus.
        layers_hog_keyboard_focus = true;
        # If true, animates manual window resizing.
        animate_manual_resizes = false;
        # If true, will animate windows being dragged by mouse.
        animate_mouse_windowdragging = false;
        # If true, the config will not reload on save.
        disable_autoreload = false;
        # Enable window swallowing
        enable_swallow = false;
        # Whether Hyprland should focus on apps that request focus.
        focus_on_activate = false;
        # Whether mouse moving to another monitor will focus that monitor.
        mouse_move_focuses_monitor = true;
        # Starts rendering before monitor displays a frame.
        render_ahead_of_time = false;
        # How many ms of safezone to add to rendering.
        render_ahead_safezone = 1;
        # If true, will allow you to restart a lockscreen app (redscreen of death)
        allow_session_lock_restore = false;
        # Change the background colour
        # NOTE: Needs disable_hyprland_logo = true
        background_color = "0x111111";
        # Close the special workspace if last window is closed.
        close_special_on_empty = true;
        # If there is an app fullscreen, new window replaces it.
        # 0 = behind
        # 1 = takes over
        # 2 = unfullscreen
        new_window_takes_over_fullscreen = 0;
        # If true, closing a fullscreen window makes the next focused window fullscreen.
        exit_window_retains_fullscreen = false;
        # If enabled, windows will open on the workspace they were invoked on.
        # 0 = disabled
        # 1 = single-shot
        # 2 = persistent (all children)
        initial_workspace_tracking = 1;
        # Whether to enable middle click paste.
        middle_click_paste = true;
        # The maximum limit for render unfocused windows' fps in background.
        render_unfocused_fps = 15;
        # Disable the warning if XDG environment is externally managed.
        disable_xdg_env_checks = false;
      };

      #############################
      # Hyprland Binds
      #############################

      # https://wiki.hyprland.org/Configuring/Variables/#binds

      ###################
      # Hyprland XWayland
      ###################

      # Check if a client is using XWayland with 'hyprctl clients'
      xwayland = {
        # Allow running apps using X11
        enabled = true;
        # Uses the nearest neighbour filtering.
        use_nearest_neighbor = true;
        # Forces a scale of 1 on xwayland windows on scaled displays.
        force_zero_scaling = true;
      };

      ###################
      # Hyprland OpenGL
      ###################

      # https://wiki.hyprland.org/Configuring/Variables/#opengl

      opengl = {
        # Reduce flicking on NVIDIA GPUs
        nvidia_anti_flicker = true;
        # Force introspection at all times to reduce GPU usage.
        # 0 = nothing
        # 1 = force always
        # 2 = force always on if nvidia is detected
        force_introspection = 2;
      };

      ###################
      # Hyprland Render
      ###################

      # https://wiki.hyprland.org/Configuring/Variables/#render

      render = {
        # Whether to enable explicit sync support.
        # 0 = no
        # 1 = yes
        # 2 = auto
        explicit_sync = 2;
        # Whether to enable explicit sync support for KMS.
        explicit_sync_kms = 2;
        # Enables direct scanout. Attempts to reduce lag.
        direct_scanout = true;
      };

      ####################
      # Cursor
      ####################

      # https://wiki.hyprland.org/Configuring/Variables/#cursor

      cursor = {
        no_hardware_cursors = true;
      };

      #############################
      # Hyprland Environment Variables
      #############################

      # See https://wiki.hyprland.org/Configuring/Environment-variables/

      env = [
        "CLUTTER_BACKEND,wayland"
        "GDK_BACKEND,wayland,x11"
        "GDK_SCALE,1"
        "HYPRCURSOR_SIZE,32"
        "MOZ_DISABLE_RDD_SANDBOX,1"
        "MOZ_ENABLE_WAYLAND,1"
        "PROTON_ENABLE_NGX_UPDATER,1"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "QT_QPA_PLATFORM,wayland"
        "SDL_VIDEODRIVER,wayland"
        "WLR_DRM_NO_ATOMIC,1"
        "WLR_NO_HARDWARE_CURSORS,1"
        "WLR_RENDERER_ALLOW_SOFTWARE,1"
        "WLR_USE_LIBINPUT,1"
        "XCURSOR_SIZE,32"
        "XWAYLAND_NO_GLAMOR,1" # This requires gamescope for gaming
        "_JAVA_AWT_WM_NONREPARENTING=1"
        "__GL_GSYNC_ALLOWED,1"
        "__GL_MaxFramesAllowed,1"
        "__GL_VRR_ALLOWED,1"
      ];

      ###################
      # Hyprland Programs
      ###################

      # https://wiki.hyprland.org/Configuring/Keywords/

      "$terminal" = "cosmic-term";

      "$fileManager" = "cosmic-files";

      "$menu" = "cosmic-launcher";

      "$switcher" = "rofi window";

      # Open apps on startup
      exec-once = [
        "$terminal"
        "swww-daemon & sleep 3 && exec random-wallpaper ''$XDG_WALLPAPERS_DIR"
        "ags run"
        "sleep 60 ; pidof insync || insync start"
      ];

      ####################
      # Hyprland Windows and Workspaces
      ####################

      # https://wiki.hyprland.org/Configuring/Window-Rules/
      # https://wiki.hyprland.org/Configuring/Workspace-Rules/

      windowrulev2 = [
        # Ignore maximize requests from apps.
        "suppressevent maximize, class:.*"
        # Fix some dragging issues with XWayland
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
        # Don't blur windows with no title or class.
        "noblur,class:^()$,title:^()$"
      ];

      #########################
      # Hyprland Dwindle Layout
      #########################

      # https://wiki.hyprland.org/Configuring/Dwindle-Layout/

      dwindle = {
        # Enable psuedotiling where windows retain their floating size when tiled.
        pseudotile = true;
        # Force split
        # 0 = split follows mouse
        # 1 = always split left
        # 2 = always split right
        force_split = 0;
        # If enabled, the split will not change regardless of what happens to the container.
        preserve_split = true;
        # If enabled, allows more precise control over the windoe split direction.
        smart_split = false;
        # If enabled, resizing direction is determined by the mouse position.
        smart_resizing = false;
        # If enabled, makes the preselect direction persist until either
        # this is turned off or another direction is selected.
        permanent_direction_override = false;
        # Specifies the scale factor of windows on the special workspace 0-1
        special_scale_factor = 1.0;
        # The auto-split width
        split_width_multiplier = 1.0;
        # Whether to prefer the active window or mouse position for splits.
        use_active_for_splits = true;
        # The default split ratio
        default_split_ratio = 1.0;
        # Which window will receive the larger half of the split
        # 0 = positional
        # 1 = current window
        # 2 = opening window
        split_bias = 0;
      };

      ###################
      # Hyprland Master Layout
      ###################

      # https://wiki.hyprland.org/Configuring/Master-Layout/

      master = {
        # master = new window becomes master.
        # slave = new window becomes slave.
        # inherit = inherit from focused window.
        #new_status = slave;
      };

      ###################
      # Hyprland Gestures
      ###################

      # https://wiki.hyprland.org/Configuring/Gestures/

      gestures = {
        # Whether to enable workspace swipe gestures.
        workspace_swipe = false;
        # How many fingers for touchpad gesture.
        workspace_swipe_fingers = 3;
        # If enabled, workspace_swipe_fingers is the minimum number of fingers required.
        workspace_swipe_min_fingers = false;
        # In px, the distance of the touchpad gesture.
        workspace_swipe_distance = 300;
        # Enable workspace swiping from the edge of a touchscreen.
        workspace_swipe_touch = false;
        # Invert the direction (touchpad only).
        workspace_swipe_invert = true;
        # Invert the direction (touchscreen only).
        workspace_swipe_touch_invert = false;
        # Minimum speed in px per timepoint to force the change ignoring cancel_ratio.
        # Setting to 0 will disable this mechanic.
        workspace_swipe_min_speed_to_force = 30;
        # How much the swipe has to proceed in order to commence it.
        # (0.7 -> if > 0.7 * distance, switch, if less, revert) [0.0 - 1.0]
        workspace_swipe_cancel_ratio = 0.5;
        # Whether a swipe right on the last workspace should create a new one.
        workspace_swipe_create_new = true;
        # If enabled, switching direction will be locked when you swipe past the direction_lock_threshold (touchpad only).
        workspace_swipe_direction_lock = true;
        # In px, the distance to swipe before direction lock activates (touchpad only).
        workspace_swipe_direction_lock_threshold = 10;
        # If enabled, swiping will not clamp at the neighboring workspaces but continue to the further ones.
        workspace_swipe_forever = false;
        # If enabled, swiping will use the r prefix instead of the m prefix for finding workspaces.
        workspace_swipe_use_r = false;
      };

      ###################
      # Hyprland Keybindings
      ###################

      # See https://wiki.hyprland.org/Configuring/Binds/

      "$mainMod" = "SUPER";

      bind = [
        # Exec
        "$mainMod, E, exec, $fileManager"
        "$mainMod, L, exec, $lock"
        "$mainMod, Q, exec, $terminal"
        "$mainMod, R, exec, $menu"
        "$mainMod, S, exec, $screenshot"
        # Other
        "$mainMod, C, killactive"
        "$mainMod, M, exit"
        "$mainMod, V, togglefloating"
        "$mainMod, P, pseudo, # dwindle"
        "$mainMod, J, togglesplit, # dwindle"
        # Focus
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        # Workspace
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"
        # Move active window
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"
        # Scroll Workspace
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
        # Resize window
        # https://wiki.hyprland.org/Configuring/Dispatchers/#list-of-dispatchers
        "bindm = $mainMod, mouse:272, movewindow" # Middle mouse button
        "bindm = $mainMod, mouse:273, killactive" # Right mouse button
        # Multimedia
        "$mainMod, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        "$mainMod, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        "$mainMod, XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        "$mainMod, XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        "$mainMod, XF86MonBrightnessUp, exec, brightnessctl s 10%+"
        "$mainMod, XF86MonBrightnessDown, exec, brightnessctl s 10%-"
        # Media via playerctl
        "$mainMod, XF86AudioNext, exec, playerctl next"
        "$mainMod, XF86AudioPause, exec, playerctl play-pause"
        "$mainMod, XF86AudioPlay, exec, playerctl play-pause"
      ];
    };

    extraConfig = ''
    '';
  };
}
