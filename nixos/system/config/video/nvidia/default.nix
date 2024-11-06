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
      "nvidia"
    ];

    blacklistedKernelModules = [
      "amdgpu"
      "i915"
    ];

    kernelParams = [
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
      powerManagement.enable = false;
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
  };
}
