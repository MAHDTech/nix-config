{ pkgs, ... }:
{
  programs.htop = {
    enable = true;

    package = pkgs.htop;

    settings = {
      color_scheme = 5;
      cpu_count_from_one = 0;
      delay = 15;
      highlight_base_name = 1;
      highlight_megabytes = 1;
      highlight_threads = 1;
      fields = [
        # PID
        0
        # USER
        48
        # PRI
        17
        # NICE
        18
        # M_SIZE
        38
        # M_RESIDENT
        39
        # M_SHARE
        40
        # STATE
        2
        # PERCENT_CPU
        46
        # PERCENT_MEM
        47
        # TIME
        49
        # COMM
        1
      ];
      left_meter_modes = [
        1
        1
        1
        2
      ];
      left_meters = [
        "AllCPUs2"
        "Memory"
        "Swap"
        "Zram"
      ];
      right_meter_modes = [
        2
        2
        2
        2
      ];
      right_meters = [
        "Tasks"
        "LoadAverage"
        "Uptime"
        "Systemd"
      ];
    };
  };
}
