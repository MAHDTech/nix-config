{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [
    overskride
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
