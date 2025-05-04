{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    bluez
    bluez-alsa
    bluez-experimental
    bluez-tools
    overskride
  ];

  services.blueman.enable = false; # Use overskride instead

  hardware.bluetooth = {
    enable = true;
    package = pkgs.bluez;
    #package = pkgs.bluez-experimental;
    powerOnBoot = true;
    hsphfpd.enable = false; # conflicts with wireplumber
    # Bluez settings
    # https://github.com/bluez/bluez/blob/master/src/main.conf
    settings = {
      General = {
        ControllerMode = "dual"; # Both BR/EDR and LE are enabled
        Enable = "Source,Sink,Media,Socket";
        Experimental = "true"; # Enable DBUS experimental interfaces
        FastConnectable = "true";
        KernelExperimental = "false"; # Enables kernel experimental features via UUID.
      };
      Policy = {
        AutoEnable = "true";
      };
      LE = {
        EnableAdvMonInterleaveScan = "true";
      };
    };
    disabledPlugins = [ ];
  };

  # Impermanence for Bluetooth
  # https://nixos.wiki/wiki/Impermanence
  #environment.persistence."/persistent" = {
  #  directories = [
  #    "/var/lib/bluetooth"
  #  ];
  #};
}
