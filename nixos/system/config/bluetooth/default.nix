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
        # Both BR/EDR and LE. "bredr" here previously switched LE off on the
        # adapter entirely, which contradicted the KernelExperimental line
        # below: that UUID exists to enable ISO sockets for BAP, and BAP is an
        # LE profile that cannot run in BR/EDR-only mode. The symptom was
        # bluetoothd failing every LE profile at startup --
        #   bap_adapter_probe()  Unable to create BAP instance   -> bap: (22)
        #   csis_server_probe()  Unable to create CSIP instance  -> csis: (22)
        # -- while classic pairing kept working, so adapters looked healthy.
        # The wider cost was that no BLE peripheral of any kind could connect.
        ControllerMode = "dual";
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
