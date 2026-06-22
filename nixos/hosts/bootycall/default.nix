{ lib, ... }:
{
  boot = {
    kernelParams = [
      "console=ttyMSM0,115200n8"
      "earlycon=msm_serial,0x078B0000"
      "deferred_probe_timeout=30"
    ];

    initrd = {
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 22;
          hostKeys = [ /etc/secrets/initrd/ssh_host_ed25519_key ];
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvQpgd14xx/ZZeIFzoa2ztmk0MNjHObmIbbnkxzCSvV mahdtech@local"
          ];
        };
      };
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
