{ pkgs, ... }:
{
  systemd = {
    services = {
      # Kernel level OOM
      "config-mglru" = {
        enable = true;
        after = [ "basic.target" ];
        wantedBy = [ "sysinit.target" ];
        script =
          let
            inherit (pkgs) coreutils;
          in
          ''
            ${coreutils}/bin/echo Y > /sys/kernel/mm/lru_gen/enabled
            ${coreutils}/bin/echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms
          '';
      };
    };

    oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
      settings.OOM = {
        DefaultMemoryPressureDurationSec = "30s";
      };
    };

    slices."background".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "10%";
    };

    user.slices."app".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "10%";
    };

    user.slices."background".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "10%";
    };
  };
}
