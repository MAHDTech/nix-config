{
  config,
  pkgs,
  ...
}: {
  imports = [];

  # NOTES:
  #   - NVIDIA QUADRO Workstation GPU

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
  ];

  boot = {
    initrd.kernelModules = [
      "nvidia"
    ];

    blacklistedKernelModules = [
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
      prime.offload.enable = false;
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  services.xserver.videoDrivers = [
    "nvidia"
  ];

  environment.variables = {
  };
}
