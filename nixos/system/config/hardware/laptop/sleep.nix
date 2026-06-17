{ pkgs, lib, ... }: {
  # Re-enable systemd targets that were disabled/masked in systemd/default.nix (SOE)
  systemd.targets = {
    sleep.enable = lib.mkForce true;
    suspend.enable = lib.mkForce true;
    hibernate.enable = lib.mkForce true;
    hybrid-sleep.enable = lib.mkForce true;
  };

  # Logging services for sleep/wake
  systemd.services = {
    laptop-sleep-log = {
      description = "Log sleep event to persistent storage";
      before = [ "sleep.target" ];
      wantedBy = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "sleep-log" ''
          echo "$(date --rfc-3339=ns): System entering sleep/suspend" >> /var/log/sleep.log
          sync
        '';
      };
    };

    laptop-wake-log = {
      description = "Log wake event to persistent storage";
      after = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      wantedBy = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "wake-log" ''
          echo "$(date --rfc-3339=ns): System woke up from sleep/suspend" >> /var/log/sleep.log
          sync
        '';
      };
    };
  };
}
