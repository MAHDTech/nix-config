# CIX P1 HDMI/DP Audio Configuration — Stub
#
# Status: PENDING UPSTREAM DRIVER
# The CIX README explicitly lists "DP Sound | TODO" as of 2026-05-07.
# https://github.com/cixtech/cix-linux-main
#
# Audio architecture on CIX P1 (Sky1):
#   - Controller: CIX IPBLOQ HD Audio (SND_HDA_CIX_IPBLOQ) — not yet in patches-7.0
#   - DSP: Tensilica HiFi5 (communicated via CIX_DSP IPC driver — now enabled in kernel)
#   - Firmware: dsp_fw.bin installed via cix-dsp-firmware.nix
#   - UCM2 profiles: included in sky1-firmware (dd81690, 2026-02-10)
#
# When SND_HDA_CIX_IPBLOQ lands in cix-linux-main patches-7.0:
#   1. Add to kernel.nix configurePhase:
#        ./scripts/config --module SND_HDA_CIX_IPBLOQ
#        ./scripts/config --module SND_SOC_CIX
#   2. Populate this file with ALSA UCM card configuration
#   3. PipeWire will automatically pick up HDMI/DP audio via the ALSA interface
#
# Bluetooth audio: works without any changes here.
#   MT7925E assumed in original plan, but live device has Intel AX210.
#   AX210 BT is hci0 (USB), handled by btusb + bluetooth stack.
#   PipeWire/WirePlumber handles BT audio automatically.
{
  # No CIX-specific audio configuration required until SND_HDA_CIX_IPBLOQ driver ships.
  # PipeWire handles Bluetooth audio (AX210 BT via btusb) without any host-specific changes.
}
