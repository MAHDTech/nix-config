{ pkgs, ... }:
{
  boot.initrd.kernelModules = [
    "panthor" # Modern ARM Mali CSF GPUs (G720, G615, etc.)
    "panfrost" # Legacy/Standard ARM Mali GPUs (Valhall, Bifrost, Midgard)
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = false;
  };

  environment.systemPackages = with pkgs; [
    # Monitoring tool specifically compiled with panthor support
    nvtopPackages.panthor

    # Mesa utilities (glxinfo, etc) for debugging
    mesa-demos
  ];
}
