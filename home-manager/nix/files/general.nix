{config, ...}: {
  home.file = {
    # Electron flags for apps like VSCode
    "electron-flags" = {
      target = "${config.home.homeDirectory}/.config/electron-flags.conf";
      executable = false;

      text = ''
        --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer
        --ozone-platform-hint=auto
        --ozone-platform=wayland
      '';
    };

    # Sommelierrc for ChromeOS
    "sommelierrc" = {
      target = "${config.home.homeDirectory}/.sommelierrc";
      executable = false;

      text = ''
        #!/usr/bin/env sh

        ###################################################
        # Name: .sommelierrc
        # Description: per-user sommelier options.
        #
        # Notes:
        #   PPI = √(pixels_horizontal^2 + pixels_vertical^2) / inches_diagonal
        #
        # References:
        #   https://chromium.googlesource.com/chromiumos/platform2/+/HEAD/vm_tools/sommelier/
        #   https://www.infobyip.com/detectmonitordpi.php
        #   https://www.sven.de/dpi/
        #
        ###################################################

        #########################
        # Variables
        #########################

        # Name used for displaying on-screen messages.
        SCRIPT_NAME="''${0##*/}"
        SCRIPT_NAME="''${SCRIPT_NAME:=UNKNOWN}"

        # Default is a scale factor of 1
        export MONITOR_SCALE_FACTOR="1"

        ########################
        # Monitor DPI
        ########################

        # Put your actual monitors DPI here.
        # You can find this either in the manufacturer specs or run the command
        # sudo get-edid | parse-edid

        # Generic (comment this out)
        export MONITOR_DPI="110"

        # Alienware AW3423DW (3440x1440 34")
        # export MONITOR_DPI="110"

        # Dell U2713HM (2560x1440 27")
        #export MONITOR_DPI="109"

        # HP Z43 (3840x2160 42.5")
        # export MONITOR_DPI="104"

        #########################
        # Functions
        #########################

        log_notice() {

            MESSAGE="''${1}"

            logger --priority=user.notice "''${MESSAGE}" || {
                return 1
            }

        }

        #########################
        # X11
        #########################

        log_notice "''${SCRIPT_NAME}: Setting DPI for X11 to ''${MONITOR_DPI}"

        # Set default X resources at startup.
        if [ -f ~/.Xresources ];
        then
          xrdb -merge ~/.Xresources
        fi

        # Set the DPI for applications that read from X
        echo "Xft.dpi: ''${MONITOR_DPI}" | xrdb -merge

        RESULT=$(xrdb -query | grep Xft.dpi)
        log_notice "''${SCRIPT_NAME}: Result ''${RESULT}"

        # Dynamically determine what the scale factor should be.
        if type xdpyinfo 2>/dev/null;
        then

          MONITOR_SCALE_FACTOR=$(xdpyinfo | awk -F'[ x]+' '/resolution/ {printf "%3.0f", $3 / 96; exit}')

          # If the command fails and is empty, set this default.
          MONITOR_SCALE_FACTOR="''${MONITOR_SCALE_FACTOR:-1}"

        else

          MONITOR_SCALE_FACTOR="1"

        fi

        log_notice "''${SCRIPT_NAME}: Monitor scale factor ''${MONITOR_SCALE_FACTOR}"

        #########################
        # GNOME
        #########################

        log_notice "''${SCRIPT_NAME}: Exporting variables for GNOME applications..."

        # Set the DPI for GDK (Gtk/GNOME) applications
        export GDK_SCALE_DPI="''${MONITOR_DPI}"

        # Set the scale factor for GDK (Gtk/GNOME) applications.
        export GDK_SCALE="''${MONITOR_SCALE_FACTOR}"
        export GDK_DPI_SCALE="''${MONITOR_SCALE_FACTOR}"

        #########################
        # Sommelier
        #########################

        log_notice "''${SCRIPT_NAME}: Exporting variables for Sommelier..."

        # Set the scale factor for Sommerlier globally (can be overridden per-app)
        export SOMMELIER_SCALE="''${MONITOR_SCALE_FACTOR}"

        # EOF
      '';
    };
  };
}
