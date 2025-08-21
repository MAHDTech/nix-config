{
  services.system76-scheduler = {
    enable = true;

    useStockConfig = false;

    settings = {
      cfsProfiles = {
        enable = true;
        default = {
          preempt = "voluntary";
        };
      };

      processScheduler = {
        pipewireBoost.enable = false;
        foregroundBoost.enable = false;
      };
    };

    assignments = {
      batch = {
        class = "batch";
        matchers = [
          "bazel"
          "clangd"
          "rust-analyzer"
        ];
      };
    };

    exceptions = [
      "include descends=\"schedtool\""
      "include descends=\"nice\""
      "include descends=\"chrt\""
      "include descends=\"taskset\""
      "include descends=\"ionice\""

      "schedtool"
      "nice"
      "chrt"
      "ionice"

      "dbus"
      "dbus-broker"
      "rtkit-daemon"
      "taskset"
      "systemd"
    ];
  };
}
