{
  services = {
    clamav = {

      # ClamAV Daemon
      daemon = {
        enable = true;
        # https://linux.die.net/man/5/clamd.conf
        settings = {
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
}
