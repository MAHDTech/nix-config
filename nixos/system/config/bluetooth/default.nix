{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    cosmic-settings
    bluez
    bluez-alsa
    bluez-experimental
    bluez-tools
  ];

  services.blueman.enable = false; # Using cosmic-settings instead

  hardware.bluetooth = {
    enable = true;
    #package = pkgs.bluez;
    package = pkgs.bluez-experimental;
    powerOnBoot = true;
    hsphfpd.enable = false; # conflicts with wireplumber
    # Bluez settings
    # https://github.com/bluez/bluez/blob/master/src/main.conf
    settings = {
      General = {
        #ControllerMode = "dual"; # Both BR/EDR and LE are enabled
        ControllerMode = "bredr"; # Only BR/EDR is enabled
        Experimental = "true"; # Enable DBUS experimental interfaces
        FastConnectable = "true";
        KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e"; # Enable ISO sockets for BAP
      };
      Policy = {
        AutoEnable = "true";
      };
      LE = {
        EnableAdvMonInterleaveScan = 0;
      };
    };
    disabledPlugins = [ ];
  };
}
