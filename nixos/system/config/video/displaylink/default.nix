{
  config,
  lib,
  pkgs,
  ...
}:
{
  # DisplayLink USB docking station support via the EVDI kernel module.
  # Provides USB-attached external displays, USB hub, and Ethernet passthrough.
  #
  # Usage: import this module in your host configuration to enable DisplayLink
  # dock support. The dock's displays will appear as additional DRM outputs
  # (e.g. card1 via platform-evdi.0).
  #
  # Requirements:
  #   - The DisplayLink driver binary blob must be pre-fetched into the Nix store.
  #     Run: nix-shell -p displaylink --arg config '{ allowUnfree = true; }'
  #     and follow the instructions to download the driver.
  #   - nixpkgs.config.allowUnfree = true (or equivalent) must be set.
  #
  # References:
  #   - https://wiki.nixos.org/wiki/Displaylink
  #   - https://www.synaptics.com/products/displaylink-graphics

  # Load the EVDI (Extensible Virtual Display Interface) out-of-tree kernel module.
  # EVDI is the open-source kernel driver that DisplayLink's userspace daemon
  # communicates with to create virtual display outputs over USB.
  boot.extraModulePackages = [ config.boot.kernelPackages.evdi ];
  boot.kernelModules = [ "evdi" ];

  # Register the DisplayLink video driver so the display manager and compositor
  # can use it. On Wayland compositors (Hyprland, Sway, etc.), the evdi DRM
  # device appears as an additional card (e.g. /dev/dri/card1).
  services.xserver.videoDrivers = [
    "displaylink"
    "modesetting"
  ];

  # Enable the DisplayLink Manager (dlm) userspace daemon.
  # This service communicates with the EVDI kernel module to manage USB-attached
  # displays. It must be running for DisplayLink monitors to function.
  systemd.services.dlm.wantedBy = [ "multi-user.target" ];

  # Install the DisplayLink userspace package (proprietary binary blob).
  environment.systemPackages = [ pkgs.displaylink ];

  # For Wayland compositors using wlroots (Hyprland, Sway), set the render
  # device so the compositor knows which GPU to use for rendering. The EVDI
  # device does not have a render node, so we point to the primary GPU.
  # Adjust the path if your primary GPU render device is different.
  environment.variables = {
    # Tell wlroots-based compositors which render device to use for EVDI outputs.
    # This should point to the primary GPU's render node, NOT the EVDI device.
    # On Qualcomm (freedreno): /dev/dri/renderD128
    # On Intel: /dev/dri/renderD128
    # On NVIDIA: may differ — check /dev/dri/by-path/
    WLR_EVDI_RENDER_DEVICE = lib.mkDefault "/dev/dri/renderD128";
  };
}
