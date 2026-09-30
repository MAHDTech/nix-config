{ pkgs, ... }:
{
  imports = [
    ../graphics
  ];

  # Mesa and hardware acceleration for Adreno (Snapdragon X Elite)
  hardware.graphics.qcom.enable = true;

  environment.systemPackages = with pkgs; [
    # Monitoring tool specifically compiled with Qualcomm MSM support
    nvtopPackages.msm

    # Mesa utilities (glxinfo, etc) for debugging
    mesa-demos

    # Vulkan tools (vulkaninfo, vkcube) — needs to be here for PATH, not in extraPackages
    vulkan-tools
  ];

  environment.variables = {
    # Keep the OpenGL VSync policy; Vulkan applications select their own present mode.
    vblank_mode = "3";
  };
}
