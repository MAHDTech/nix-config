{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [
    ffmpeg-full # Includes H.264, VP8, VP9 codecs
    libva # Hardware acceleration support (if applicable)
    #gstreamer
    #gst-plugins-base
    #gst-plugins-good
  ];

  security.rtkit.enable = true;

  services = {
    # Pulseaudio disabled in favor of PipeWire
    pulseaudio.enable = false;

    pipewire = {
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
          "10-sample-rate" = {
            "context.properties" = {
              "default.clock.rate" = 96000;
              "default.clock.allowed-rates" = [
                96000
                48000
                44100
                32000
              ];
              "default.clock.quantum" = 256;
              "default.clock.min-quantum" = 256;
              "default.clock.max-quantum" = 1024;
            };
          };
          "10-resample" = {
            "stream.properties" = {
              "resample.disable" = false;
              "resample.quality" = 10;
            };
          };
          "10-alsa-linear-volume" = {
            "alsa.properties" = {
              "alsa.volume-method" = "linear";
            };
          };
        };
        pipewire-pulse = {
          "92-low-latency" = {
            "context.properties" = [
              {
                name = "libpipewire-module-protocol-pulse";
                args = { };
              }
            ];
            "pulse.properties" = {
              "pulse.min.req" = "256/96000";
              "pulse.default.req" = "256/96000";
              "pulse.max.req" = "1024/96000";
              "pulse.min.quantum" = "256/96000";
              "pulse.max.quantum" = "1024/96000";
            };
            "stream.properties" = {
              "node.latency" = "32/96000";
              "resample.quality" = 1;
            };
          };
        };
        pipewire = {
          "10-clock-rate" = {
            "context.properties" = {
              "default.clock.rate" = 96000;
            };
          };
          "11-no-upmixing" = {
            "stream.properties" = {
              "channelmix.upmix" = true;
            };
          };
        };
        jack = { };
      };

      alsa = {
        enable = true;
        support32Bit = true;
      };

      audio.enable = true;

      jack.enable = false;

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
                    # Matches Sony WH-1000XM5
                    # wpctl status to get the device id
                    # wpctl inspect <device id> to get the match details.
                    "device.name" = "~bluez_card.*";
                    "device.product.id" = "0x0df0";
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
                "aptx"
                "aptx_hd"
                "aptx_ll"
                "aptx_ll_duplex"
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
          "11-bluetooth-policy" = {
            "wireplumber.settings" = {
              "bluetooth.autoswitch-to-headset-profile" = false;
            };
          };
          "50-alsa-config" = {
            "monitor.alsa.rules" = [
              {
                matches = [
                  {
                    "node.name" = "~alsa_output.*";
                  }
                ];
                actions = {
                  update-props = {
                    "api.alsa.period-size" = 1024;
                    "api.alsa.period-num" = 4;
                    "api.alsa.headroom" = 8192;
                    "api.alsa.disable-batch" = false;
                    "api.alsa.disable-tsched" = false;
                  };
                };
              }
            ];
          };
          "80-disable-logind" = {
            "wireplumber.profiles" = {
              "main" = {
                "monitor.bluez.seat-monitoring" = "disabled";
              };
            };
          };
        };
      };
    };
  };

  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "@audio";
      item = "rtprio";
      type = "-";
      value = "99";
    }
    {
      domain = "@audio";
      item = "nofile";
      type = "soft";
      value = "99999";
    }
    {
      domain = "@audio";
      item = "nofile";
      type = "hard";
      value = "99999";
    }
  ];

  services.udev.extraRules = ''
    DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
    DEVPATH=="/devices/virtual/misc/hpet", OWNER="root", GROUP="audio", MODE="0660"
    KERNEL=="hpet", GROUP="audio"
    KERNEL=="rtc0", GROUP="audio"
  '';
}
