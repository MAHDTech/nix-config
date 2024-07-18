{...}: {
  systemd.user = {
    startServices = true;

    services = {};
  };
}
