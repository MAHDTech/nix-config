{ pkgs, lib, ... }:
{
  # Snapdragon X Elite (ARM64) power management
  #
  # Previous configuration force-disabled all power management and hardlocked
  # CPU frequencies to 1.92 GHz as a workaround for PMIC overcurrent resets.
  # Root cause analysis revealed the resets were caused by:
  #   - Missing ARM_SCMI_POWERCAP kernel config (no firmware power budget enforcement)
  #   - ADSP blacklisted (broke PMIC power cooperation loop)
  #   - fw_devlink sync_state() prematurely disabling regulators/power domains
  #
  # NOTE: clk_ignore_unused and pd_ignore_unused are still required in the base
  # kernel params (matches Ubuntu's linux-qcom-x1e). regulator_ignore_unused is
  # only in the power-safe specialisation as a rollback safety net.
  #
  # With those root causes addressed, power management is now enabled and
  # frequency scaling is handled by firmware (SCMI + GMU + LMH).

  # TODO: Test with NO power management enabled.
  powerManagement.enable = lib.mkForce false;

  # Override the battery device name to point to Snapdragon native path
  services.batteryNotifier.device = "qcom-battmgr-bat";

  # zram swap for memory pressure relief
  # Laptop has 30 GiB RAM — zram gives ~60 GiB effective with zstd compression
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100; # Prefer zram over any disk swap
  };

  # PMIC telemetry logger — writes CPU/GPU frequencies and thermal data to
  # /dev/pmsg0 at 1-second intervals for post-crash forensics via pstore.
  systemd.services.pmic-telemetry-logger = {
    description = "High-frequency PMIC Telemetry Logger (Ramoops pmsg0)";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "pmic-telemetry-logger" ''
        while true; do
          timestamp=$(${pkgs.coreutils}/bin/date +%T.%3N)
          cpu_cur_freqs=$(${pkgs.coreutils}/bin/cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)
          cpu_freqs=$(echo "$cpu_cur_freqs" | ${pkgs.coreutils}/bin/tr "\n" "," | ${pkgs.gnused}/bin/sed "s/,$//")
          gpu_freq=$(${pkgs.coreutils}/bin/cat /sys/class/devfreq/3d00000.gpu/cur_freq 2>/dev/null)
          temp_vals=$(${pkgs.coreutils}/bin/cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null)
          temps=$(echo "$temp_vals" | ${pkgs.coreutils}/bin/tr "\n" "," | ${pkgs.gnused}/bin/sed "s/,$//")
          echo "[$timestamp] CPU_FREQS:$cpu_freqs GPU:$gpu_freq TEMPS:$temps" > /dev/pmsg0
          ${pkgs.coreutils}/bin/sleep 1
        done
      '';
      Restart = "always";
      RestartSec = "1s";
    };
  };
}
