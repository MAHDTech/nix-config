{
  config,
  pkgs,
  lib,
  ...
}:
let
  normalUsers = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;
  downloadsPaths = map (u: "${u.home}/Downloads") (lib.attrValues normalUsers);
in
{
  services = {
    clamav = {

      # ClamAV Daemon
      daemon = {
        enable = true;
        # https://linux.die.net/man/5/clamd.conf
        settings = {
          OnAccessPrevention = true;
          OnAccessIncludePath = [ "/tmp" ] ++ downloadsPaths;
        };
      };

      # ClamAV Updater
      updater = {
        enable = true;
        interval = "daily";
        frequency = 12;
        # https://linux.die.net/man/5/freshclam.conf
        settings = {
        };
      };

      # ClamAV Fangfrisch Updater (Downloads community/unofficial signatures)
      fangfrisch = {
        enable = true;
      };

      # ClamAV On-Access Real-time Scanner
      clamonacc = {
        enable = true;
      };

      # ClamAV Scanner
      scanner = {
        enable = true;
        interval = "Sat *-*-* 04:00:00";
        scanDirectories = [
          "/etc"
          "/home"
          "/tmp"
          "/var/lib"
          "/var/tmp"
        ];
      };
    };
  };

  systemd.services.clamdscan = {
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.bash}/bin/bash -c '${config.services.clamav.package}/bin/clamdscan --multiscan --fdpass --infected --allmatch ${lib.concatStringsSep " " config.services.clamav.scanner.scanDirectories} 2> >(${pkgs.gnugrep}/bin/grep -v \"cli_realpath: Invalid arguments\" >&2); EXIT_CODE=$?; wait; exit $EXIT_CODE'";
    };
  };
}
