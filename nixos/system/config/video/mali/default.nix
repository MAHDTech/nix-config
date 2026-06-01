{ pkgs, ... }:
{
  # Panthor for CSF-based Mali GPUs (G720, G615, etc.)
  # Loaded via boot.kernelModules in host hardware-configuration.nix
  # NOTE: panfrost is for older non-CSF GPUs (Bifrost/Midgard) — do NOT load both

  hardware.graphics = {
    enable = true;
    enable32Bit = false;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers # GPU driver debugging (Panthor/Immortalis-G720)
    ];
  };

  environment.systemPackages = with pkgs; [
    # Monitoring tool specifically compiled with panthor support
    nvtopPackages.panthor

    # Mesa utilities (glxinfo, etc) for debugging
    mesa-demos
  ];
}
