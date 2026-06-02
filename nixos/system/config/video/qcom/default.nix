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
    # Force VSync/frame limits on Qualcomm Snapdragon GPU to prevent overcurrent regulator watchdogs
    vblank_mode = "3";
    MESA_VK_WSI_PRESENT_MODE = "fifo";
  };
}
