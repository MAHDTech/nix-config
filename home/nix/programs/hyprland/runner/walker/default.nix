{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    elephant
    walker
  ];

  systemd.user.services.elephant = {
    Unit = {
      Description = "Elephant data provider for Walker";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.elephant}/bin/elephant";
      Restart = "on-failure";
      Type = "simple";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  xdg = {
    configFile = {
      "walker-config" = {
        source = ./config.toml;
        target = "walker/config.toml";
      };

      "walker-themes-tars-dark-css" = {
        source = ./themes/tars_dark.css;
        target = "walker/themes/tars_dark/style.css";
      };

      "walker-themes-tars-light-css" = {
        source = ./themes/tars_light.css;
        target = "walker/themes/tars_light/style.css";
      };

      "walker-themes-tars-synthwave-css" = {
        source = ./themes/tars_synthwave.css;
        target = "walker/themes/tars_synthwave/style.css";
      };
    };
  };
}
