{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  security.pam = {
    u2f = {
      enable = true;
      settings.cue = true;
      control = "sufficient";
    };

    services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
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
