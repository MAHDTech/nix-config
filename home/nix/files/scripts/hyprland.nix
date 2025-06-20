{
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
  ];

  home.file = {
    "hyprlock-force-unlock" = {
      target = "${config.home.homeDirectory}/.local/bin/hyprland-force-unlock";
      executable = true;

      text = ''
        #!${pkgs.bash}/bin/bash

        echo "Forcing hyprlock session unlock"

        # Make sure we have the deps in the path.
        type hyprctl 2>/dev/null || {
          echo "hyprctl not found in the path!"
          exit 1
        }

        # Force kill any running hyprlock instances
        pkill --full hyprlock || true

        # Permit screen unlock for this session
        hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1' || {
          echo "Failed to permit screen unlock for this session"
          exit 1
        }

        # Exec hyprlock
        hyprctl --instance 0 'dispatch exec hyprlock' || {
          echo "Failed to exec hyprlock"
          exit 1
        }

        echo "hyprlock session has been unlocked. You may now return to the desktop."
        exit 0
      '';
    };
  };
}
