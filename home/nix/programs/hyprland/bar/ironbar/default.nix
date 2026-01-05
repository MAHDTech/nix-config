{
  inputs,
  pkgs,
  ...
}:
let

  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  unstablePkgs = with pkgsUnstable; [
    ironbar # v0.18+ is GTK4
  ];

in
{

  home.packages =
    with pkgs;
    [
      ironbar
      zafiro-icons
    ]
    ++ unstablePkgs;

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
