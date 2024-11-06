{
  # NOTE: Reminder that TLP conflicts with auto-cpufreq.

  services.auto-cpufreq = {
    enable = true;

    settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };

      charger = {
        governor = "ondemand";
        turbo = "auto";
      };
    };
  };
}
