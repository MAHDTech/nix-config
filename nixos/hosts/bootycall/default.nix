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
          hostKeys = [ /etc/secrets/initrd/ssh_host_ed25519_key ];
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkDYJ0EnGd7wkoW4MCz9bjgEHVoGZcwv5veeTr3/Gke"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLEPFnH5qCksDIv/vcbm7H7p+OWEqiqKyWdAtEo+/UU"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvQpgd14xx/ZZeIFzoa2ztmk0MNjHObmIbbnkxzCSvV mahdtech@local"
          ];
        };
      };

      systemd.services.panic-timer = {
        wantedBy = [ "initrd.target" ];
        script = ''
          sleep 45
          echo "=== REGULATORS STATE ===" > /dev/kmsg || true
          for r in /sys/class/regulator/regulator.*; do
            if [ -f "$r/name" ]; then
              echo "$(cat "$r/name"): $(cat "$r/microvolt" 2>/dev/null || echo unknown) uV, state: $(cat "$r/state" 2>/dev/null || echo unknown)" > /dev/kmsg || true
            fi
          done
          echo "=== CLOCK SUMMARY ===" > /dev/kmsg || true
          mount -t debugfs none /sys/kernel/debug || true
          if [ -f /sys/kernel/debug/clk/clk_summary ]; then
            cat /sys/kernel/debug/clk/clk_summary > /dev/kmsg || true
          else
            echo "debugfs/clk_summary not found" > /dev/kmsg || true
          fi
          echo "=== USB DEVICES ===" > /dev/kmsg || true
          lsusb -t > /dev/kmsg 2>&1 || true
          echo "=== PANICKING NOW ===" > /dev/kmsg || true
          echo 1 > /proc/sys/kernel/sysrq || true
          echo c > /proc/sysrq-trigger || true
        '';
      };

      systemd.services.panic-on-fail = {
        wantedBy = [ "emergency.target" ];
        script = ''
          echo "INITRD FAILED! PANICKING!" > /dev/kmsg || true
          echo 1 > /proc/sys/kernel/sysrq || true
          echo c > /proc/sysrq-trigger || true
        '';
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
