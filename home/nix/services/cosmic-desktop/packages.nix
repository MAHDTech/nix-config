##################################################
# Desktop packages
##################################################

# NOTES:
# - These were previously carried by the Hyprland home module, which acted as
#   the de-facto desktop package set. They are all compositor-agnostic and
#   remain useful under COSMIC.
# - The cosmic-* applications themselves live in
#   nixos/system/config/desktop-environment/cosmic.nix at the system level.
#   Do not restate them here.

{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # Terminal (config lives in home/nix/files/ghostty)
    ghostty

    # Display / output control
    brightnessctl
    cosmic-randr

    # Screenshot and annotation
    grim
    slurp
    swappy
    wayshot

    # Wayland utilities
    wayland-pipewire-idle-inhibit
    wayland-utils
    wl-clipboard

    # Audio
    pavucontrol

    # Misc
    libnotify
    lz4
    nvd
  ];
}
