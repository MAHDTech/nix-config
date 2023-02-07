{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  systemd = {

    extraConfig = ''
      DefaultTimeoutStartSec=15s
      DefaultTimeoutStopSec=15s
    '';

    timers.suspend-on-low-battery = {

      wantedBy = [ "multi-user.target" ];

      timerConfig = {
        OnUnitActiveSec = "120";
        OnBootSec= "120";
      };

    };

    services = {

      suspend-on-low-battery =
        let

          battery-level-sufficient = pkgs.writeShellScriptBin "battery-level-sufficient" ''
            test "$(cat /sys/class/power_supply/BAT0/status)" != Discharging \
            || test "$(cat /sys/class/power_supply/BAT0/capacity)" -ge 5
          '';

        in {

          serviceConfig = { Type = "oneshot"; };
          onFailure = [ "suspend.target" ];
          script = "${lib.getExe battery-level-sufficient}";

        };

    };

  };

}