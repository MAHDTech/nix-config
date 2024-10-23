{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
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
  
  };

  programs.hyprland = {
    enable = true;
    xwayland = {
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
