{

  systemd = {
    settings.Manager = {
      WatchdogDevice = "/dev/watchdog"; # Path to the hardware watchdog device
      RuntimeWatchdogSec = "2m"; # Time before reboot if systemd doesn't respond
      RebootWatchdogSec = "10m"; # Grace period after reboot command before hardware forces reboot
      KExecWatchdogSec = "10m"; # Grace period after kexec (kernel reload) before hardware reboot
    };
  };

}
