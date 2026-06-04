{ pkgs, lib, ... }:
{
  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };

  environment = {
    systemPackages = with pkgs; [
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
      tuigreet

      # XDG
      xdg-utils
      xdg-launch
    ];

    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      COSMIC_DATA_CONTROL_ENABLED = "1";

      # Fix 1Password desktop integration for authentication dialogue boxes.
      GTK_USE_PORTAL = "1";

      # Force Hyprland to use Panthor (card1) for hardware rendering, displaying on card0
      AQ_DRM_DEVICES = "/dev/dri/card1:/dev/dri/card0";
      WLR_DRM_DEVICES = "/dev/dri/card1:/dev/dri/card0";
    };

    variables = {
      QT_QPA_PLATFORMTHEME = lib.mkForce "gtk4";
    };
  };

  services = {
    xserver = {
      enable = true;
      updateDbusEnvironment = true;
    };
    # User level idle daemon is being used.
    #hypridle.enable = true;
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

    config = {
      common = {
        default = [
          "gtk"
        ];
        "org.freedesktop.impl.portal.Settings" = [
          "gtk"
        ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        # Enable secret portal for authentication dialogue boxes (like 1password SSH)
        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
        "org.freedesktop.impl.portal.Settings" = [
          "gtk"
        ];
      };
    };

    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };

  security = {
    polkit = {
      enable = true;
    };
    pam = {
      services = {
        hyprlock = { };
      };
    };
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
          ${pkgs.tuigreet}/bin/tuigreet \
          --asterisks \
          --cmd "uwsm start hyprland-uwsm.desktop" \
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
