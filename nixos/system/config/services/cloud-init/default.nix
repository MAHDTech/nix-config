{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cloud-init-diagnostics;
in
{
  options.services.cloud-init-diagnostics = {
    enable = lib.mkEnableOption "cloud-init console diagnostics";
    console = lib.mkOption {
      type = lib.types.str;
      default = "tty1";
      description = "Kernel console receiving userspace output; tty1 is the Prism VGA console.";
    };
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "root" ];
      description = "Accounts whose SSH authorized-key file presence is reported.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.cloud-init ];
    services.cloud-init = {
      enable = true;
      settings.output.all = lib.mkDefault "| ${pkgs.coreutils}/bin/tee -a /var/log/cloud-init-output.log";
      # NixOS does not install cloud-init's upstream logging configuration.
      settings.logcfg = lib.mkDefault ''
        [loggers]
        keys=root
        [handlers]
        keys=console,file
        [formatters]
        keys=detail
        [logger_root]
        level=DEBUG
        handlers=console,file
        [handler_console]
        class=StreamHandler
        level=WARNING
        formatter=detail
        args=(sys.stderr,)
        [handler_file]
        class=FileHandler
        level=DEBUG
        formatter=detail
        args=('/var/log/cloud-init.log', 'a')
        [formatter_detail]
        format=%(asctime)s - %(filename)s[%(levelname)s]: %(message)s
      '';
    };

    # The last console parameter receives userspace output, including cloud-init.
    boot.kernelParams = lib.mkAfter [ "console=${cfg.console}" ];
    systemd.services."getty@".serviceConfig.TTYVTDisallocate = false;

    systemd.services.cloud-init-report = {
      description = "Report cloud-init and SSH access readiness";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "cloud-final.service"
      ]
      ++ lib.optional (
        config.services.openssh.enable && config.services.openssh.generateHostKeys
      ) "sshd-keygen.service";
      after = [
        "cloud-final.service"
      ]
      ++ lib.optional (
        config.services.openssh.enable && config.services.openssh.generateHostKeys
      ) "sshd-keygen.service";
      path = [
        pkgs.cloud-init
        pkgs.coreutils
        pkgs.getent
        pkgs.iproute2
        pkgs.openssh
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
      script = ''
        echo "========== cloud-init report =========="
        cloud-init status --long || true
        echo "Runtime hostname: $(hostnamectl --transient)"
        static_hostname="$(hostnamectl --static)"
        echo "Static hostname: ''${static_hostname:-(unset)}"
        ip -brief address show || true
        echo "Failed cloud-init units:"
        systemctl list-units --failed --no-pager --no-legend 'cloud-*.service' || true
        for user in ${lib.escapeShellArgs cfg.users}; do
          entry="$(getent passwd "$user")" || entry=""
          if [ -z "$entry" ]; then
            echo "$user: account lookup failed"
            continue
          fi
          home_dir="$(echo "$entry" | cut -d: -f6)"
          if [ -s "$home_dir/.ssh/authorized_keys" ]; then
            echo "$user: authorized_keys present (SSH policy still applies)"
          else
            echo "$user: no authorized_keys in home directory"
          fi
        done
        ${lib.optionalString config.services.openssh.enable ''
          echo "SSH host key fingerprints:"
          for key in ${
            lib.escapeShellArgs (map (key: "${key.path}.pub") config.services.openssh.hostKeys)
          }; do
            if [ -s "$key" ]; then
              ssh-keygen -lf "$key" || true
            else
              echo "$key: not available yet"
            fi
          done
        ''}
        echo "Logs: /var/log/cloud-init.log and /var/log/cloud-init-output.log"
        echo "======================================="
      '';
    };
  };
}
