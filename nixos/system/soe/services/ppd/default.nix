{
  # Standardize on power-profiles-daemon globally (managed via SOE)
  services.power-profiles-daemon.enable = true;

  # Ensure TLP is disabled as it conflicts with power-profiles-daemon.
  services.tlp.enable = false;
}
