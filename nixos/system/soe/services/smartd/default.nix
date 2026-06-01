_: {
  # System-wide disk health monitoring via S.M.A.R.T.
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.wall.enable = true; # Warn logged-in users directly of impending failure
  };
}
