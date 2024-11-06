{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [
  ];

  hardware = {
    pulseaudio.enable = false;
  };

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    systemWide = true;
    socketActivation = true;

    wireplumber = {
      enable = true;
      package = pkgs.wireplumber;
      extraConfig = {
        bluetoothEnhancements = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = ["hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag"];
          };
        };
      };
    };

    alsa.enable = true;
    alsa.support32Bit = true;
    audio.enable = true;
    jack.enable = true;
    pulse.enable = true;
  };
}
