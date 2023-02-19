{ inputs, config, lib, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  sound.enable = true;

  hardware.pulseaudio.enable = false;

  nixpkgs.config.pulseaudio = false;

  security.rtkit.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  services.pipewire = {

    enable = true;

    audio = {

      enable = true;

    };

    wireplumber.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    jack.enable = true;

    config = {

      pipewire = {


      };

      client = {


      };

    };

    media-session = {

      config = {

        media-session = {

          context.modules = [

            {
              args = { };
              flags = [
                "ifexists"
                "nofail"
              ];
              name = "libpipewire-module-rtkit";
            }

            {
              name = "libpipewire-module-protocol-native";
            }

            {
              name = "libpipewire-module-client-node";
            }

            {
              name = "libpipewire-module-client-device";
            }

            {
              name = "libpipewire-module-adapter";
            }

            {
              name = "libpipewire-module-metadata";
            }

            {
              name = "libpipewire-module-session-manager";
            }

          ];

          context.properties = { };
          /*
          context.spa-libs = {
            api.alsa.* = "alsa/libspa-alsa";
            api.bluez5.* = "bluez5/libspa-bluez5";
            api.libcamera.* = "libcamera/libspa-libcamera";
            api.v4l2.* = "v4l2/libspa-v4l2";
          };
          */

          session.modules = {

            default = [
              "flatpak"
              "portal"
              "v4l2"
              "suspend-node"
              "policy-node"
            ];

            with-alsa = [
              "with-audio"
            ];

            with-audio = [
              "metadata"
              "default-nodes"
              "default-profile"
              "default-routes"
              "alsa-seq"
              "alsa-monitor"
            ];

            with-jack = [
              "with-audio"
            ];

            with-pulseaudio = [
              "with-audio"
              "bluez5"
              "bluez5-autoswitch"
              "logind"
              "restore-stream"
              "streams-follow-default"
            ];

          };

        };

        bluez-monitor = {

          properties = {

            bluez5.sbc-xq-support = true;

            bluez5.msbc-support = true;

            bluez5.enable-faststream = true;

            bluez5.headset-roles = [
              "hfp_hf"
            ];

             bluez5.auto-connect  = [
              "a2dp_sink"
              "hfp_hf"
            ];

            # http://soundexpert.org/articles/-/blogs/audio-quality-of-sbc-xq-bluetooth-audio-codec
            # Enabled A2DP codecs (default: all).
            # NOTES:
            #   LDAC        Sony 990kbps / 24-bit
            #   SBC-XQ      SBC-XQ 730kbps / 16-bit (sbc-xq enabled)
            #   APTX HD     Qualcomm 576 kbps / 24-bit
            #   APTX        Qualcomm 384 kbps / 16-bit
            #   AAC         Apple 264 kbps / 16-bit
            #   SBC         SBC 328 kbps / 16-bit (sbc-xq disabled)
            bluez5.codecs = [
                #"aac"
                #"aptx"
                #"aptx_hd"
                #"aptx_ll"
                #"aptx_ll_duplex"
                #"faststream"
                #"faststream_duplex"
                "ldac"
                #"sbc"
                "sbc_xq"
            ];

            bluez5.enable-hw-volume = true;

            bluez5.hw-volume = [
              "a2dp_sink"
              "a2dp_source"
              #"hfp_ag"
              "hfp_hf"
              #"hsp_ag"
              #"hsp_hs"
            ];

            bluez5.a2dp.ldac.quality  = "auto";

            device.profile = "a2dp-sink";

            bluez5.dummy-avrcp-player = true;

          };

          rules = [

            {
              actions = {
                update-props = {
                  bluez5.auto-connect = [
                    "hfp_hf"
                    "hsp_hs"
                    "a2dp_sink"
                  ];
                };
              };
              matches = [
                {
                  device.name = "~bluez_card.*";
                }
              ];
            }

            {
              actions = {

                update-props = {
                  node.pause-on-idle = false;
                };

              };

              matches = [

                {
                  # Matches all sinks
                  node.name = "~bluez_input.*";
                }

                {
                  # Matches all sources
                  node.name = "~bluez_output.*";
                }

              ];
            }

          ];

        };

      };

    };

  };

}