{ pkgs, ... }:
{
  # Mesa and hardware acceleration for Adreno (Snapdragon X Elite)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-utils
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
    ];
  };

  environment.systemPackages = with pkgs; [
    # Monitoring tool specifically compiled with Qualcomm MSM support
    nvtopPackages.msm

    # Mesa utilities (glxinfo, etc) for debugging
    mesa-demos
  ];

  environment.variables = {
    # Force Mesa to use the freedreno driver if needed (though it should auto-detect)
    # GALLIUM_DRIVER = "freedreno";
    # MESA_LOADER_DRIVER_OVERRIDE = "msm";
  };
}
