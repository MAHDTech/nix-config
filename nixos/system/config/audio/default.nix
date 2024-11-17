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
    raopOpenFirewall = true;

    extraLv2Packages = [
      pkgs.lsp-plugins
    ];

    # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-client
    extraConfig = {
      client = {
        "10-resample" = {
          "stream.properties" = {
            "resample.disable" = false;
            "resample.quality" = 14;
          };
        };
      };
    };

    alsa = {
      enable = true;
      support32Bit = true;
    };

    audio.enable = true;

    jack.enable = true;

    pulse.enable = true;

    # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/conf_file.html
    wireplumber = {
      enable = true;
      package = pkgs.wireplumber;
      # wpctl status
      extraConfig = {
        "log-level-debug" = {
          "context.properties" = {
            # Notice = 'N', Debug = 'D'
            "log.level" = "N";
          };
        };
        "wh-1000xm5-ldac-hq" = {
          "monitor.bluez.rules" = [
            {
              matches = [
                {
                  # Match any bluetooth device with ids equal to that of a WH-1000XM5
                  "device.name" = "~bluez_card.*";
                  "device.product.id" = "0x0cd3";
                  "device.vendor.id" = "usb:054c";
                }
              ];
              actions = {
                update-props = {
                  # Set quality to high quality instead of the default of auto
                  "bluez5.a2dp.ldac.quality" = "hq";
                };
              };
            }
          ];
        };
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
              "hsp_hs"
              "hsp_ag"
              # Headset Profile Hands-Free/Audio Gateway
              "hfp_hf"
              "hfp_ag"
            ];
          };
        };
        "11-bluetooth-policy" = {
          "wireplumber.settings" = {
            "bluetooth.autoswitch-to-headset-profile" = false;
          };
        };
        "80-disable-logind" = {
          "wireplumber.profiles" = {
            "main" = {
              "monitor.bluez.seat-monitoring" = "disabled";
            };
          };
        };
        "51-disable-suspension" = {
          "monitor.alsa.rules" = [
            {
              matches = [
                {
                  # Matches all sources
                  "node.name" = "~alsa_input.*";
                }
                {
                  # Matches all sinks
                  "node.name" = "~alsa_output.*";
                }
              ];
              actions = {
                update-props = {
                  "session.suspend-timeout-seconds" = 0;
                };
              };
            }
          ];
        };
        "10-bluez-disable-suspension" = {
          "monitor.bluez.rules" = [
            {
              matches = [
                {
                  # Matches all sources
                  "node.name" = "~bluez_input.*";
                }
                {
                  # Matches all sinks
                  "node.name" = "~bluez_output.*";
                }
              ];
              actions = {
                update-props = {
                  "session.suspend-timeout-seconds" = 0;
                };
              };
            }
          ];
        };
      };
    };
  };
}
