{ pkgs, ... }:
{
  stylix = {
    enable = true;

    # catppuccin-mocha base16 scheme — same palette, architecture-agnostic
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    # Generate a solid color background as wallpaper at build time
    # This prevents any network dependencies or hash mismatches
    image =
      pkgs.runCommand "stylix-wallpaper.png"
        {
          nativeBuildInputs = [ pkgs.imagemagick ];
        }
        ''
          convert -size 1920x1080 xc:"#1e1e2e" $out
        '';

    polarity = "dark";

    fonts = {
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sizes = {
        applications = 11;
        terminal = 13;
        desktop = 11;
        popups = 11;
      };
    };

    targets.plymouth.enable = true;
    targets.grub.enable = false;
  };
}
