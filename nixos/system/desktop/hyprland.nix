{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Hyprland
    pyprland
    hyprpicker
    hyprcursor
    hyprlock
    hypridle
    hyprpaper

    # Terminal
    kitty

    # Greeter
    greetd.tuigreet
  ];

  services = {
    xserver = {
      enable = true;
      updateDbusEnvironment = true;
    };

    displayManager = {
      sddm.enable = false;
    };

    # Idle daemon
    hypridle.enable = true;
  };

  programs = {
    hyprland = {
      enable = true;
      xwayland = {
        enable = true;
      };
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    # Lock screen utility
    hyprlock = {
      enable = true;
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
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
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --time-format '%I:%M %p | %a • %h | %F' --cmd Hyprland";
        user = "greeter";
      };
    };
  };
}
