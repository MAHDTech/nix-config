{ pkgs, ... }:
{
  # Mesa and hardware acceleration for Adreno (Snapdragon X Elite)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-utils
      vulkan-loader
      vulkan-validation-layers
    ];
  };

  environment.systemPackages = with pkgs; [
    # Monitoring tool specifically compiled with Qualcomm MSM support
    nvtopPackages.msm

    # Mesa utilities (glxinfo, etc) for debugging
    mesa-demos

    # Vulkan tools (vulkaninfo, vkcube) — needs to be here for PATH, not in extraPackages
    vulkan-tools
  ];

  environment.variables = {
    # Force VSync/frame limits on Qualcomm Snapdragon GPU to prevent overcurrent regulator watchdogs
    vblank_mode = "3";
    MESA_VK_WSI_PRESENT_MODE = "fifo";
  };
}
