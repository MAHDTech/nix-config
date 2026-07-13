{
  wayland.desktopManager.cosmic.idle = {
    # The time in milliseconds before the screen turns off.
    # Active preference: Some(1800000) (30 minutes)
    screen_off_time = {
      __type = "optional";
      value = 1800000;
    };

    # The time in milliseconds before the system suspends when on AC power.
    # Active preference: None (Never)
    suspend_on_ac_time = {
      __type = "optional";
      value = null;
    };

    # The time in milliseconds before the system suspends when on battery power.
    # No active local preference found, setting to default 90000 (1.5 minutes)
    suspend_on_battery_time = {
      __type = "optional";
      value = 90000;
    };
  };
}
