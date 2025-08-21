{
  # Make sure throttled is disabled (conflicts with thermald)
  services.throttled.enable = false;

  services.thermald.enable = true;
}
