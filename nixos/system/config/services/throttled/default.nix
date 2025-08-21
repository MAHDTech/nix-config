{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [ ];

  # Make sure thermald is disabled (conflicts with throttled)
  services.thermald.enable = false;

  services.throttled = {
    enable = true;
  };
}
