{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [
    overskride
  ];

  hardware.bluetooth = {
    enable = true;
    package = pkgs.bluez;
    powerOnBoot = true;
    hsphfpd.enable = false;
    # Bluez settings
    # https://github.com/bluez/bluez/blob/3818b99c764efe84cd3455081f6392c256564085/src/main.conf
    settings = {
      General = {
        ControllerMode = "dual";
        Enable = "Source,Sink,Media,Socket";
        Experimental = "true";
        FastConnectable = "true";
      };
      Policy = {
        AutoEnable = "true";
      };
      LE = {
        EnableAdvMonInterleaveScan = "true";
      };
    };
    disabledPlugins = [
    ];
  };
}
