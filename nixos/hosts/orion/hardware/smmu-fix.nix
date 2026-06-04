{ pkgs, ... }:
let
  smmuScript = pkgs.writeShellScript "smmu-evtq-fix" ''
    val=""
    # devmem2 output ends with the read value, e.g. "0x1D"
    for word in $(${pkgs.devmem2}/bin/devmem2 0x0b010020 2>/dev/null); do
      val=$word
    done
    case "$val" in
      0x*)
        # Clear EVENTQEN (bit 2, value 4)
        new_val=$(printf "0x%X" $((val & 0xFFFFFFFB)))
        echo "Current SMMU CR0: $val, disabling EVENTQEN: $new_val"
        ${pkgs.devmem2}/bin/devmem2 0x0b010020 w $new_val >/dev/null
        ;;
      *)
        echo "Error: Could not read SMMU CR0 register (val: $val)"
        exit 1
        ;;
    esac
  '';
in
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

  boot.initrd.systemd.storePaths = [
    smmuScript
    pkgs.devmem2
  ];

  boot.initrd.systemd.services.smmu-evtq-fix-initrd = {
    description = "Disable SMMUv3 event queue in initrd (IORT firmware bug workaround)";
    wantedBy = [ "sysinit.target" ];
    before = [ "sysinit.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${smmuScript}";
    };
  };

  systemd.services.smmu-evtq-fix = {
    description = "Disable SMMUv3 event queue (IORT firmware bug workaround)";
    wantedBy = [ "sysinit.target" ];
    before = [
      "systemd-modules-load.service"
      "systemd-udev-trigger.service"
      "network-pre.target"
    ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${smmuScript}";
    };
  };
}
