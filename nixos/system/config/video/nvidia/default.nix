{
  config,
  pkgs,
  ...
}: {
  imports = [];

  # NOTES:
  #   - NVIDIA QUADRO T400

  environment.systemPackages = with pkgs; [
    egl-wayland
    nvidia-vaapi-driver
    nvtopPackages.full
  ];

  boot = {
    initrd.kernelModules = [
      "fbdev"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
    ];

    blacklistedKernelModules = [
      "amdgpu"
      "i915"
    ];

    kernelParams = [
      "nvidia-drm.hdmi_deepcolor=1"
      "nvidia_drm.fbdev=1"
      "nvidia_drm.modeset=1"
      "nvidia_drm.runpm=1"
    ];
  };

  hardware = {
    graphics = {
      enable = true;

      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
        nvidia-vaapi-driver
      ];

      extraPackages32 = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
        nvidia-vaapi-driver
      ];
    };

    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      forceFullCompositionPipeline = true;
      prime = {
        offload.enable = false;
        sync.enable = false;
        reverseSync.enable = false;
      };
    };
  };

  services.xserver.videoDrivers = [
    "nvidia"
  ];

  environment.variables = {
    GBM_BACKEND = "nvidia-drm";
    LIBSEAT_BACKEND = "logind";
    LIBVA_DRIVER_NAME = "nvidia";
    MOZ_ENABLE_WAYLAND = "1";
    NVD_BACKEND = "direct";
    QT_QPA_PLATFORM = "wayland";
    WLR_NO_HARDWARE_CURSORS = "1";
    XDG_SESSION_TYPE = "wayland";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_GSYNC_ALLOWED = "1";
    __NV_PRIME_RENDER_OFFLOAD = "1";
    __VK_LAYER_NV_optimus = "NVIDIA_only";
  };
}
