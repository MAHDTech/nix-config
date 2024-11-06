{
  config,
  pkgs,
  ...
}: {
  imports = [];

  # NOTES:
  #   - NVIDIA QUADRO T400

  environment.systemPackages = with pkgs; [
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
      ];

      extraPackages32 = with pkgs; [
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
  };
}
