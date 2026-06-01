{ pkgs, ... }:
# Device-specific firmware blobs extracted from Windows.
#
# These are NOT available in upstream linux-firmware and must be kept:
#   - qcadsp8380.mbn / adsp_dtbs.elf  — OEM-signed ADSP firmware
#   - qccdsp8380.mbn / cdsp_dtbs.elf  — OEM-signed CDSP firmware
#   - qcdxkmsuc8380.mbn               — GPU kernel-mode driver (Hamoa/X1E die)
#   - qcdxkmsucpurwa.mbn              — GPU kernel-mode driver (Purwa/X1P die)
#   - *.jsn                           — pd-mapper subsystem descriptors
#
# The following are NOW upstream in linux-firmware and no longer bundled:
#   - ath12k/WCN7850 WiFi firmware
#   - Audio topology (X1E80100-ASUS-Zenbook-A14-tplg.bin)
#   - Generic ADSP/CDSP (adsp.mbn, cdsp.mbn)
#   - GPU zap shader (gen70500_zap.mbn)
#   - QUPv3 firmware (qupv3fw.elf)
pkgs.runCommand "zenbook-firmware"
  {
    srcFirmware = ../files/firmware;
  }
  ''
    mkdir -p $out/lib/firmware

    # Copy the device-specific extracted blobs
    cp -r --no-preserve=mode,ownership $srcFirmware/* $out/lib/firmware/
  ''
