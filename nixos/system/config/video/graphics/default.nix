{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.hardware.graphics = {
    amd.enable = lib.mkEnableOption "AMD graphics extra packages";
    intel.enable = lib.mkEnableOption "Intel graphics extra packages";
    nvidia.enable = lib.mkEnableOption "NVIDIA graphics extra packages";
    mali.enable = lib.mkEnableOption "Mali graphics extra packages";
    qcom.enable = lib.mkEnableOption "Qualcomm graphics extra packages";
  };

  config = {
    hardware.graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault pkgs.stdenv.hostPlatform.isx86_64;

      extraPackages =
        (lib.optionals config.hardware.graphics.amd.enable (
          with pkgs;
          [
            # Linux firmware collection
            linux-firmware
            # AMD Video Processing Library GPU runtime for hardware video processing
            vpl-gpu-rt
            # Vulkan loader for graphics APIs
            vulkan-loader
            # OpenCL support for AMD GPUs
            rocmPackages.clr.icd
            # Additional Mesa packages for better compatibility
            mesa.llvmPackages.libclang
          ]
        ))
        ++ (lib.optionals config.hardware.graphics.intel.enable (
          with pkgs;
          [
            # OpenCL and Level Zero compute runtime for 12th Gen and newer Intel ARC GPUs
            intel-compute-runtime
            # Level Zero GPU backend driver (libze_intel_gpu.so) for GPU compute workloads
            intel-compute-runtime.drivers
            # Hardware video acceleration driver for modern Intel GPUs (supports both iHD and ARC)
            intel-media-driver
            # Intel Video Processing Library GPU runtime for hardware video processing
            vpl-gpu-rt
          ]
        ))
        ++ (lib.optionals config.hardware.graphics.nvidia.enable (
          with pkgs;
          [
            vaapiVdpau
            libvdpau-va-gl
            nvidia-vaapi-driver
          ]
        ))
        ++ (lib.optionals config.hardware.graphics.mali.enable (
          with pkgs;
          [
            vulkan-loader
            vulkan-tools
            vulkan-validation-layers # GPU driver debugging (Panthor/Immortalis-G720)
          ]
        ))
        ++ (lib.optionals config.hardware.graphics.qcom.enable (
          with pkgs;
          [
            libva-utils
            vulkan-loader
            vulkan-validation-layers
          ]
        ));

      extraPackages32 =
        (lib.optionals (config.hardware.graphics.amd.enable && pkgs.stdenv.hostPlatform.isx86_64) (
          with pkgs;
          [
            # Linux firmware collection (32-bit)
            linux-firmware
            # AMD Video Processing Library GPU runtime (32-bit)
            vpl-gpu-rt
            # Vulkan loader for graphics APIs (32-bit)
            vulkan-loader
          ]
        ))
        ++ (lib.optionals (config.hardware.graphics.intel.enable && pkgs.stdenv.hostPlatform.isx86_64) (
          with pkgs;
          [
            # OpenCL and Level Zero compute runtime for 12th Gen and newer Intel ARC GPUs (32-bit)
            intel-compute-runtime
            # Level Zero GPU backend driver (32-bit)
            intel-compute-runtime.drivers
            # Intel Video Processing Library GPU runtime (32-bit)
            vpl-gpu-rt
          ]
        ))
        ++ (lib.optionals (config.hardware.graphics.nvidia.enable && pkgs.stdenv.hostPlatform.isx86_64) (
          with pkgs;
          [
            vaapiVdpau
            libvdpau-va-gl
            nvidia-vaapi-driver
          ]
        ));
    };
  };
}
