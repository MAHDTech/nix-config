{
  config,
  pkgs,
  lib,
  ...
}:
let
  normalUsers = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;
  downloadsPaths = map (u: "${u.home}/Downloads") (lib.attrValues normalUsers);

  # Third-party signatures causing false positives (without .UNOFFICIAL suffix)
  # cspell:ignore Sanesecurity Porcupine wsdl sgen ign2
  ignoredSignatures = [
    # Overly broad Sanesecurity rule matching any PE with a 4-char InternalName (e.g. Proton wine-mono wsdl.exe, sgen.exe)
    "Porcupine.Malware.58887"
  ];

  localWhitelist = pkgs.writeText "clamav-local.ign2" (
    lib.concatMapStrings (sig: "${sig}\n") ignoredSignatures
  );
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

  systemd = {
    tmpfiles.rules = [
      "L+ /var/lib/clamav/local.ign2 - - - - ${localWhitelist}"
    ];

    services = {
      clamav-daemon.reloadTriggers = [ localWhitelist ];

      clamdscan.serviceConfig = {
        ExecStart = lib.mkForce "${pkgs.bash}/bin/bash -c '${config.services.clamav.package}/bin/clamdscan --multiscan --fdpass --infected --allmatch ${lib.concatStringsSep " " config.services.clamav.scanner.scanDirectories} 2> >(${pkgs.gnugrep}/bin/grep -v \"cli_realpath: Invalid arguments\" >&2); EXIT_CODE=$?; wait; exit $EXIT_CODE'";
      };
    };
  };
}
