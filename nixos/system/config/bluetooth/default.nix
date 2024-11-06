{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [
    overskride
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
}
