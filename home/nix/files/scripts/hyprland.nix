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
        #!${pkgs.python3}/bin/bash

        echo "Forcing hyprlock session unlock"

        # Make sure we have the deps in the path.
        type hyprctl 2>/dev/null || {
          echo "hyprctl not found in the path"
          exit 1
        }

        # Permit screen unlock for this session
        hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1'

        # Exec hyprlock
        hyprctl --instance 0 'dispatch exec hyprlock'

        echo "hyprlock session unlocked, return to desktop"
        exit 0
      '';
    };
  };
}
