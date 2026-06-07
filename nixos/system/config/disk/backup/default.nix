{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.tars-backup;

  backupScript = pkgs.writeShellScriptBin "tars-backup-script" ''
    #!/usr/bin/env bash
    set -euo pipefail

    log_info() {
      echo "[INFO] $1"
    }

    log_error() {
      echo "[ERROR] $1" >&2
    }

    UUIDS=( ${lib.concatStringsSep " " (map (x: "\"${x}\"") cfg.diskUuids)} )
    USER_NAME="${cfg.userName}"
    HOME_DIR="/home/$USER_NAME"
    FLAG_FILE="$HOME_DIR/.backup_failed"
    MOUNT_POINT="/mnt/backup"
    TARGET_DRIVE=""

    function trap_err() {
      log_error "Backup failed!"
      touch "$FLAG_FILE"
      chown "$USER_NAME:$USER_NAME" "$FLAG_FILE" || true
      umount "$MOUNT_POINT" 2>/dev/null || true
    }

    # 1. Detect drive
    for uuid in "''${UUIDS[@]}"; do
      if [ -b "/dev/disk/by-uuid/$uuid" ]; then
        TARGET_DRIVE="/dev/disk/by-uuid/$uuid"
        break
      fi
    done

    # 2. Exit gracefully if no drive
    if [ -z "$TARGET_DRIVE" ]; then
      log_info "No configured backup drive detected. Exiting gracefully."
      exit 0
    fi

    log_info "Detected backup drive: $TARGET_DRIVE"
    mkdir -p "$MOUNT_POINT"

    # Trap for error handling
    trap trap_err ERR

    # 3. Mount drive
    if ! mountpoint -q "$MOUNT_POINT";
    then
      log_info "Mounting $TARGET_DRIVE to $MOUNT_POINT"
      mount "$TARGET_DRIVE" "$MOUNT_POINT"
    fi

    REPO="$MOUNT_POINT/$(hostname)"
    export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

    # 4. Auto-initialize
    if [ ! -d "$REPO" ];
    then
      log_info "Initializing new unencrypted Borg repository at $REPO"
      ${pkgs.borgbackup}/bin/borg init --encryption=none "$REPO"
    fi

    # 5. Backup
    log_info "Starting backup for $HOME_DIR..."
    ${pkgs.borgbackup}/bin/borg create \
      --stats \
      "$REPO::{now:%Y-%m-%d_%H-%M}" \
      "$HOME_DIR" \
      --exclude "$HOME_DIR/.cache" || {
        log_error "Backup failed!"
        touch "$FLAG_FILE"
        chown "$USER_NAME:$USER_NAME" "$FLAG_FILE" || true
        umount "$MOUNT_POINT" 2>/dev/null || true
        exit 1
      }

    # 6. Prune
    log_info "Pruning old backups..."
    ${pkgs.borgbackup}/bin/borg prune \
      -v --list --keep-daily=30 "$REPO" || {
        log_error "Prune failed!"
        touch "$FLAG_FILE"
        chown "$USER_NAME:$USER_NAME" "$FLAG_FILE" || true
        umount "$MOUNT_POINT" 2>/dev/null || true
        exit 1
      }

    # 7. Unmount
    log_info "Unmounting $MOUNT_POINT..."
    umount "$MOUNT_POINT" || {
      log_error "Unmount failed!"
      touch "$FLAG_FILE"
      chown "$USER_NAME:$USER_NAME" "$FLAG_FILE" || true
      exit 1
    }

    # Clean up flag file if backup succeeded
    rm -f "$FLAG_FILE"

    log_info "Backup complete!"
  '';

in
{
  options.services.tars-backup = {
    enable = lib.mkEnableOption "TARS Backup Service";

    userName = lib.mkOption {
      type = lib.types.str;
      description = "The username whose home directory should be backed up and who receives notifications.";
    };

    diskUuids = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of allowed NVMe UUIDs to backup to.";
      example = [ "12345678-1234-1234-1234-123456789012" ];
    };
  };

  config = lib.mkIf cfg.enable {
    # System dependencies
    environment.systemPackages = with pkgs; [
      borgbackup
      vorta
    ];

    systemd = {
      services.tars-backup = {
        description = "Daily TARS Borg Backup";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${backupScript}/bin/tars-backup-script";
          User = "root"; # Run as root to mount and access all files
        };
      };

      timers.tars-backup = {
        description = "Timer for Daily TARS Borg Backup";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 00:00:00"; # Midnight daily
          Persistent = true;
        };
      };

      # Systemd User Service for graphical notification
      user.services.tars-backup-notify = {
        description = "Notify user if TARS backup failed";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        script = ''
          FLAG_FILE="$HOME/.backup_failed"
          if [ -f "$FLAG_FILE" ]; then
            ${pkgs.libnotify}/bin/notify-send "TARS Backup Failed" "Please check the journal for details: journalctl -u tars-backup.service" -u critical -i dialog-error
            rm -f "$FLAG_FILE"
          fi
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "yes";
        };
      };
    };
  };
}
