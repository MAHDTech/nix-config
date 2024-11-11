{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [
  ];

  hardware = {
    pulseaudio.enable = false;
  };

  security.rtkit.enable = true;

  services.blueman.enable = true;

  services.pipewire = {
    enable = true;

    systemWide = false;
    socketActivation = true;

    # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/conf_file.html
    wireplumber = {
      enable = true;
      package = pkgs.wireplumber;
      # wpctl status
      extraConfig = {
        "10-bluez" = {
          "monitor.bluez.properties" = {
            "bluez.codecs" = [
              "aac"
              #"aptx"
              #"aptx_hd"
              #"aptx_ll"
              #"aptx_ll_duplex"
              "ldac"
              "sbc"
              "sbc_hbr"
              "sbc_hbr_plus"
              "sbc_xq"
            ];
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.hfphsp-backend" = "native";
            "bluez5.roles" = [
              # AD2P Audio Sink/Source
              "a2dp_sink"
              "a2dp_source"
              # Low Energy Audio Sink/Source
              "bap_sink"
              "bap_source"
              # Hands-Free Profile Headset/Audio Gateway
              #"hsp_hs"
              #"hsp_ag"
              # Headset Profile Hands-Free/Audio Gateway
              #"hfp_hf"
              #"hfp_ag"
            ];
          };
        };
        "11-bluetooth-policy" = {
          "wireplumber.settings" = {
            "bluetooth.autoswitch-to-headset-profile" = false;
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
