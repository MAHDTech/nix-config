{ pkgs, ... }:
{
  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };

  environment.systemPackages = with pkgs; [
    # Hyprland
    #pyprland
    hyprpicker
    hyprcursor
    hyprlock
    hypridle
    hyprpaper

    # Terminal
    kitty

    # Greeter
    greetd.tuigreet

    # XDG
    xdg-utils
    xdg-launch
  ];

  services = {
    xserver = {
      enable = true;
      updateDbusEnvironment = true;
    };
    # Idle daemon
    hypridle.enable = true;
  };

  programs = {
    hyprland = {
      enable = true;
      # XWayland configuration at system level
      xwayland = {
        enable = true;
      };
      withUWSM = true;
      package = pkgs.hyprland;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    # Lock screen utility
    hyprlock = {
      enable = true;
    };
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
    ];
  };

  security = {
    polkit = {
      enable = true;
    };
    pam = {
      services = {
        ags = { };
        hyprlock = { };
      };
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    COSMIC_DATA_CONTROL_ENABLED = "1";
  };

  # Greeter (GUI)
  programs.regreet = {
    enable = false;
    settings = {
    };
    extraCss = "";
    cageArgs = [
      "-s"
    ];
  };

  # Greeter (Terminal)
  services.greetd = {
    enable = true;
    restart = true;
    # https://man.sr.ht/~kennylevinsen/greetd/
    settings = {
      default_session = {
        command = ''
          ${pkgs.greetd.tuigreet}/bin/tuigreet \
          --asterisks \
          --cmd Hyprland \
          --greet-align center \
          --greeting "Welcome to NixOS" \
          --power-reboot 'shutdown -r now' \
          --power-shutdown 'shutdown -h now' \
          --remember \
          --time \
          --time-format '%I:%M %p | %a • %h | %F' \
          --width 100 \
          --theme border=magenta;text=cyan;prompt=green;time=red;action=blue;button=yellow;container=black;input=red
        '';
        user = "greeter";
      };
    };
  };
}
