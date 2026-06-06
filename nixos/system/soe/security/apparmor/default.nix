_:

{
  security = {
    apparmor = {
      enable = true;
      enableCache = false;
      includes = {
        "abstractions/base" = ''
          /dev/tty rw,
        '';
      };
      killUnconfinedConfinables = false;
      packages = [ ];
    };
    lsm = [ "apparmor" ];
  };

  services = {
    dbus = {
      apparmor = "enabled";
    };
  };
}
