{ lib, ... }:
{
  boot = {
    kernelParams = [
      "console=ttyMSM0,115200n8"
      "earlycon=msm_serial,0x078B0000"
    ];

    initrd = {
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 22;
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvQpgd14xx/ZZeIFzoa2ztmk0MNjHObmIbbnkxzCSvV mahdtech@local"
          ];
        };
      };

      preDeviceCommands = ''
        (
          sleep 45
          echo "45 SECONDS PASSED! PANICKING!" > /dev/kmsg || true
          echo 1 > /proc/sys/kernel/sysrq || true
          echo c > /proc/sysrq-trigger || true
        ) &
      '';

      preFailCommands = ''
        echo "INITRD FAILED! PANICKING!" > /dev/kmsg || true
        echo 1 > /proc/sys/kernel/sysrq || true
        echo c > /proc/sysrq-trigger || true
      '';
    };
  };

  networking = {
    hostName = "BOOTYCALL";
    hostId = "def00005";
    useDHCP = lib.mkDefault true;
  };

  imports = [
    # Hardware Configuration
    ./hardware

    # OS Services Configuration
    ./services
  ];
}
