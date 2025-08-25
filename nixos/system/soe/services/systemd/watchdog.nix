{

  systemd = {
    watchdog = {
      device = "/dev/watchdog"; # Path to the hardware watchdog device
      runtimeTime = "1m"; # Time before reboot if systemd doesn't respond
      rebootTime = "10m"; # Grace period after reboot command before hardware forces reboot
      kexecTime = "10m"; # Grace period after kexec (kernel reload) before hardware reboot
    };
  };

}
