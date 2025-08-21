{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    ironbar
  ];

  xdg = {
    configFile = {
      "ironbar-config" = {
        source = ./config.yaml;
        target = "ironbar/config.yaml";
        onChange = "${pkgs.ironbar}/bin/ironbar reload";
      };

      "ironbar-style" = {
        source = ./style.css;
        target = "ironbar/style.css";
        onChange = "${pkgs.ironbar}/bin/ironbar reload";
      };

      "ironbar-scripts" = {
        source = ./scripts;
        target = "ironbar/scripts";
        onChange = "${pkgs.ironbar}/bin/ironbar reload";
      };
    };
  };
}
