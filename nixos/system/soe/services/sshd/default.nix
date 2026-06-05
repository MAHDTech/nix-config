{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [ ];

  services.openssh = {
    enable = true;

    settings = {
      # Security hardening: key-based auth only
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
