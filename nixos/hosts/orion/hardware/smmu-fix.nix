{ pkgs, ... }:
{
  # Workaround for SMMU IORT firmware bug in EDK2 <= 1.2.1
  #
  # The IORT table only covers 25 of 32 Stream ID bits, causing every PCIe DMA
  # transaction to generate spurious C_BAD_STREAMID events. This creates an
  # interrupt storm (~130 IRQs/sec on CPU0) leading to SSH hangs, network drops,
  # and system freezes under PCIe load.
  #
  # This clears the EVTQEN bit in the SMMU CR0 register, stopping the interrupt
  # storm while PCIe DMA continues to function normally.
  #
  # Same approach used by BredOS and Ubuntu Concept images for Orion O6.
  #
  # TODO: Remove once EDK2 firmware with fixed IORT table is released.

  environment.systemPackages = [ pkgs.devmem2 ];

  systemd.services.smmu-evtq-fix = {
    description = "Disable SMMUv3 event queue (IORT firmware bug workaround)";
    wantedBy = [ "multi-user.target" ];
    after = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "smmu-evtq-fix" ''
        val=$(${pkgs.devmem2}/bin/devmem2 0x0b010020 | awk -F': ' '/Value at address/ {print $2}')
        if [ -n "$val" ]; then
          # Clear EVENTQEN (bit 2, value 4)
          new_val=$(printf "0x%X" $((val & 0xFFFFFFFB)))
          echo "Current SMMU CR0: $val, disabling EVENTQEN: $new_val"
          ${pkgs.devmem2}/bin/devmem2 0x0b010020 w $new_val
        else
          echo "Error: Could not read SMMU CR0 register"
          exit 1
        fi
      '';
    };
  };
}
