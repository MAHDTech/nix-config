{ inputs, ... }:
let
  rofiModule = "${inputs.stylix}/modules/rofi/hm.nix";
  mkRofiTarget = import "${inputs.stylix}/stylix/mk-target.nix" {
    name = "rofi";
    humanName = "Rofi";
  };
in
{
  disabledModules = [ rofiModule ];
  imports = [
    (
      args:
      import rofiModule (
        args
        // {
          # The pinned module's first config sets the deprecated font option.
          # Replace that fragment and retain the upstream theme unchanged.
          # Remove this shim when Stylix adopts programs.rofi.settings.font.
          mkTarget =
            target:
            mkRofiTarget (
              target
              // {
                config = [
                  ({ fonts }: {
                    programs.rofi.settings.font = "${fonts.monospace.name} ${toString fonts.sizes.popups}";
                  })
                ]
                ++ builtins.tail target.config;
              }
            );
        }
      )
    )
  ];

  stylix.targets = {
    # Disable Zed styling because manual settings have precise font sizes
    zed.enable = false;

    # Disable Starship styling because we use our custom catppuccin palette config
    starship.enable = false;
  };
}
