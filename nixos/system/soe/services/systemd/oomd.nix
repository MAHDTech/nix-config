{pkgs, ...}: {
  systemd = {
    services = {
      "config-mglru" = {
        enable = true;
        after = ["basic.target"];
        wantedBy = ["sysinit.target"];
        script = let
          inherit (pkgs) coreutils;
        in ''
          ${coreutils}/bin/echo Y > /sys/kernel/mm/lru_gen/enabled
          ${coreutils}/bin/echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms
        '';
      };
    };

    oomd = {
      enable = true;
      enableRootSlice = false;
      enableSystemSlice = false;
      enableUserSlices = false;
      extraConfig.DefaultMemoryPressureDurationSec = "10s";
    };

    slices."background".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "10%";
    };

    user.slices."app".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "15%";
    };

    user.slices."background".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "10%";
    };
  };
}
