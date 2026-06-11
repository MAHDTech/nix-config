{ pkgs, ... }:
# Device-specific firmware blobs extracted from the Windows package provided by ASUS.
#
# These are NOT available in upstream linux-firmware and must be kept:
#   - qcadsp8380.mbn / adsp_dtbs.elf  — OEM-signed ADSP firmware (battery, audio, USB-C PD)
#   - qccdsp8380.mbn / cdsp_dtbs.elf  — OEM-signed CDSP firmware (compute DSP)
#   - qcvss8380.mbn                   — Iris video codec firmware (H.264/HEVC/VP9/AV1)
#   - qcav1e8380.mbn                  — AV1 hardware decoder firmware
#   - qcdxkmsuc8380.mbn               — OEM-signed GPU zap shader (kernel loads by THIS name)
#   - *.jsn                           — pd-mapper subsystem descriptors
#
# The following are provided by upstream linux-firmware (enableRedistributableFirmware)
# and are NOT bundled here:
#   - gen70500_gmu.bin    — GPU Management Unit (SoC-generic)
#   - gen70500_sqe.fw     — GPU SQE microcode (SoC-generic)
#   - gen70500_zap.mbn    — GPU zap shader (generic, in qcom/ not device subdir)
#   - ath12k/WCN7850/**   — WiFi firmware
#   - Audio topology files
#
# Note on GPU zap shader: the kernel DRM MSM driver loads the zap shader from a
# DEVICE-SPECIFIC path (qcom/x1e80100/ASUSTeK/zenbook-a14/qcdxkmsuc8380.mbn) as
# defined in the device tree. The generic gen70500_zap.mbn is at a different path
# (qcom/gen70500_zap.mbn). Both must be present — the OEM one may also carry
# device-specific signing.
pkgs.runCommand "zenbook-firmware"
  {
    srcFirmware = ../../files/firmware;
  }
  ''
    # Create the directory structure for both X Plus and X Elite.
    mkdir -p $out/lib/firmware/qcom/x1e80100
    mkdir -p $out/lib/firmware/qcom/x1p42100

    # Copy the device-specific OEM blobs (ADSP, CDSP, video codec, zap shader, pd-mapper descriptors)
    if [ -d $srcFirmware/qcom/x1e80100 ];
    then
      for f in $srcFirmware/qcom/x1e80100/ASUSTeK/zenbook-a14/*.mbn \
                $srcFirmware/qcom/x1e80100/ASUSTeK/zenbook-a14/*.elf \
                $srcFirmware/qcom/x1e80100/ASUSTeK/zenbook-a14/*.jsn; do
        if [ -f "$f" ];
        then
          basename=$(basename "$f")
          # Skip only Windows-only WDDM KMD artifacts that have NO Linux use.
          # qcdxkmbase8380*.bin = GMU firmware variants for Windows power modes (linux uses gen70500_gmu.bin)
          # qcvss8380_pa.mbn = power-aware variant for Windows
          # qcdxkmsucpurwa.mbn = power-related variant for Windows
          # unified_* / sequence_* = Windows GPU command stream firmware
          case "$basename" in
            qcdxkmbase8380*|qcdxkmsucpurwa*|qcvss8380_pa*)
              echo "Skipping Windows-only artifact: $basename"
              ;;
            *)
              echo "Installing OEM firmware: $basename"
              install -Dm644 "$f" "$out/lib/firmware/qcom/x1e80100/ASUSTeK/zenbook-a14/$basename"
              install -Dm644 "$f" "$out/lib/firmware/qcom/x1p42100/ASUSTeK/zenbook-a14/$basename"
              ;;
          esac
        fi
      done
    fi

    # Also install .bin files (sequence_manifest, unified_kbcs, unified_ksqs)
    # These may be GPU command processor firmware — keep them to be safe
    for f in $srcFirmware/qcom/x1e80100/ASUSTeK/zenbook-a14/*.bin; do
      if [ -f "$f" ]; then
        basename=$(basename "$f")
        case "$basename" in
          qcdxkmbase8380*)
            echo "Skipping Windows GMU variant: $basename"
            ;;
          *)
            echo "Installing OEM firmware: $basename"
            install -Dm644 "$f" "$out/lib/firmware/qcom/x1e80100/ASUSTeK/zenbook-a14/$basename"
            install -Dm644 "$f" "$out/lib/firmware/qcom/x1p42100/ASUSTeK/zenbook-a14/$basename"
            ;;
        esac
      fi
    done
  ''
