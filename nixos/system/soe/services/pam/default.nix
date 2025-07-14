{ pkgs, ... }:
{
  imports = [ ];

  environment.systemPackages = with pkgs; [ ];

  security.pam = {
    u2f = {
      enable = true;
      settings.cue = true;
      control = "sufficient";
    };

    services = {
      login.u2fAuth = true;

      # Don't enable this if you want passwordless sudo.
      # TODO: Use dedicated service account without u2f.
      sudo.u2fAuth = false;
    };

    loginLimits = [
      {
        domain = "*";
        type = "hard";
        item = "nofile";
        value = "100000";
      }
    ];
  };
}
