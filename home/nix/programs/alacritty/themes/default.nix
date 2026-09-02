{ ... }:
{
  # Choose your active Alacritty theme by importing one of the following:
  # - ./tars_synthwave.nix (Cyberpunk Neon)
  # - ./tars_dark.nix      (Pitch Dark Cyberpunk)
  # - ./tars_blue.nix      (Deep Navy Cyberpunk)
  # - ./tars_light.nix     (High Contrast Light)
  imports = [
    ./tars_synthwave.nix
  ];
}
