{ pkgs, ... }:
{
  hardware.firmware = [
    # OEM firmware: device-specific blobs NOT available in upstream linux-firmware.
    # Provides:
    #   - ADSP/CDSP (qcadsp8380.mbn, qccdsp8380.mbn)
    #   - Video codec (qcvss8380.mbn)
    #   - AV1 decoder (qcav1e8380.mbn)
    #   - pd-mapper descriptors (*.jsn)
    #   - GPU SQE microcode
    #
    # linux-firmware (via enableRedistributableFirmware)
    # Provides:
    #   - WiFi
    #   - Bluetooth
    #   - audio topology
    #   - GPU GMU/ZAP shaders
    #   - and other SoC-generic firmware.
    (pkgs.callPackage ./asus.nix { })

    # Qualcomm Windows GPU driver extraction (downloads at build time)
    # Contains updated GPU firmware (v31.0.148.0) including newer zap shader
    # and GMU variants. Same OEM blobs are already committed in files/firmware/
    # so this is disabled by default.
    # (pkgs.callPackage ./qcom.nix { })
  ];
}
