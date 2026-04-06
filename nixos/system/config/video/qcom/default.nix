{ pkgs, ... }:
{
  # Mesa and hardware acceleration for Adreno (Snapdragon X Elite)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa # Includes freedreno
      libva-utils
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
    ];
  };

  environment.variables = {
    # Force Mesa to use the freedreno driver if needed (though it should auto-detect)
    # GALLIUM_DRIVER = "freedreno";
    # MESA_LOADER_DRIVER_OVERRIDE = "msm";
  };
}
