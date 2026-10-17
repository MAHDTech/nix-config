{ lib, pkgs, ... }:
let
  agyArchiver = pkgs.writeShellApplication {
    name = "agy-archiver";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gawk
      gnugrep
      jq
      procps
      util-linux
    ];
    text = ''
      shopt -s nullglob

      log_info() {
        printf '[INFO] %s\n' "$*"
      }

      log_warn() {
        printf '[WARN] %s\n' "$*" >&2
      }

      LOCK_FILE="''${XDG_RUNTIME_DIR:-/tmp}/agy-archiver.lock"
      exec 9>"$LOCK_FILE"
      if ! flock -n 9; then
        log_info "Another agy-archiver instance is already running; exiting."
        exit 0
      fi

      # Wait briefly if wakatime-cli is actively walking brain/ or conversations/; skip this run if still busy.
      for attempt in {1..10}; do
        if ! pgrep -f "wakatime-cli.*--sync-ai-activity" >/dev/null 2>&1; then
          break
        fi
        log_info "Waiting for active wakatime-cli sync to finish (attempt ''${attempt}/10)..."
        sleep 1
      done
      if pgrep -f "wakatime-cli.*--sync-ai-activity" >/dev/null 2>&1; then
        log_warn "wakatime-cli sync is still running after 10s; deferring archival to next hourly run."
        exit 0
      fi

      NOW="$(date +%s)"
      IDLE_GRACE_SECS=$((30 * 60))
      ACTIVE_RETENTION_SECS=$((7 * 86400))
      ARCHIVE_RETENTION_SECS=$((30 * 86400))

      # wakatime-cli scans every .db in conversations/ on each sync with a 256 MiB / 5s limit.
      # Metadata columns are ~16% of file size, so 1 GiB of .db files stays well under 256 MiB.
      MAX_ACTIVE_BYTES=$((1024 * 1024 * 1024))
      MAX_ACTIVE_FILES=150

      OPEN_PATHS=""
      refresh_open_paths() {
        OPEN_PATHS="$(readlink /proc/[0-9]*/fd/* 2>/dev/null | grep -F '/.gemini/' || true)"
      }

      has_live_open_handle() {
        local uuid="$1"
        local pid
        while IFS= read -r pid; do
          [[ -n "$pid" ]] || continue
          if readlink "/proc/''${pid}/fd/"* 2>/dev/null | grep -Fq "/''${uuid}"; then
            return 0
          fi
        done < <(pgrep -u "''${UID:-$(id -u)}" -f "antigravity|agy|wakatime|sqlite" 2>/dev/null || true)
        return 1
      }

      is_open_conversation() {
        local app_dir="$1"
        local uuid="$2"
        local db="''${app_dir}/conversations/''${uuid}.db"

        if [[ -s "''${db}-wal" ]]; then
          return 0
        fi
        if [[ -n "$OPEN_PATHS" ]] && grep -Fq "/''${uuid}" <<<"$OPEN_PATHS"; then
          return 0
        fi
        return 1
      }

      get_birth_or_mtime() {
        local target="$1"
        local birth_time mtime
        birth_time="$(stat -c %W "$target" 2>/dev/null || echo 0)"
        mtime="$(stat -c %Y "$target" 2>/dev/null || echo "$NOW")"
        if [[ "$birth_time" =~ ^[0-9]+$ ]] && (( birth_time > 0 && birth_time < mtime )); then
          echo "$birth_time"
          return 0
        fi
        echo "$mtime"
      }

      declare -A USER_IDS=()

      is_user_conversation() {
        local app_dir="$1"
        local uuid="$2"

        if [[ -n "''${USER_IDS[$uuid]:-}" ]]; then
          return 0
        fi
        if [[ -f "''${app_dir}/annotations/''${uuid}.pbtxt" ]] || [[ -f "''${app_dir}/conversations-archive/''${uuid}/''${uuid}.pbtxt" ]]; then
          USER_IDS["$uuid"]=1
          return 0
        fi

        local transcript=""
        if [[ -f "''${app_dir}/brain/''${uuid}/.system_generated/logs/transcript.jsonl" ]]; then
          transcript="''${app_dir}/brain/''${uuid}/.system_generated/logs/transcript.jsonl"
        elif [[ -f "''${app_dir}/conversations-archive/''${uuid}/brain/.system_generated/logs/transcript.jsonl" ]]; then
          transcript="''${app_dir}/conversations-archive/''${uuid}/brain/.system_generated/logs/transcript.jsonl"
        fi

        if [[ -n "$transcript" ]]; then
          local first_line=""
          IFS= read -r first_line <"$transcript" || true
          if [[ "$first_line" == *'"USER_EXPLICIT"'* ]]; then
            USER_IDS["$uuid"]=1
            return 0
          fi
        fi

        return 1
      }

      archive_conversation() {
        local app_dir="$1"
        local uuid="$2"
        local reason="$3"
        local conv_dir="''${app_dir}/conversations"
        local bundle_dir="''${app_dir}/conversations-archive/''${uuid}"
        local db="''${conv_dir}/''${uuid}.db"
        local start_epoch="$NOW"

        # Re-check right before moving in case agy or wakatime-cli just opened this conversation.
        if is_open_conversation "$app_dir" "$uuid" || has_live_open_handle "$uuid"; then
          log_info "Skipping ''${uuid}: open file handle or active WAL detected."
          return 1
        fi
        if pgrep -f "wakatime-cli.*--sync-ai-activity" >/dev/null 2>&1; then
          log_warn "Deferring ''${uuid}: wakatime-cli sync started during run."
          return 1
        fi

        local sz_kb=0
        if [[ -e "$db" ]]; then
          start_epoch="$(get_birth_or_mtime "$db")"
          sz_kb=$(( $(stat -c %s "$db" 2>/dev/null || echo 0) / 1024 ))
        elif [[ -e "''${bundle_dir}/''${uuid}.db" ]]; then
          start_epoch="$(get_birth_or_mtime "''${bundle_dir}/''${uuid}.db")"
        elif [[ -d "''${app_dir}/brain/''${uuid}" ]]; then
          start_epoch="$(get_birth_or_mtime "''${app_dir}/brain/''${uuid}")"
        fi

        mkdir -p "$bundle_dir"

        for ext in "" "-wal" "-shm"; do
          if [[ -e "''${conv_dir}/''${uuid}.db''${ext}" ]]; then
            mv -f "''${conv_dir}/''${uuid}.db''${ext}" "''${bundle_dir}/" 2>/dev/null || true
          fi
        done

        if [[ -d "''${app_dir}/brain/''${uuid}" ]]; then
          if [[ ! -d "''${bundle_dir}/brain" ]]; then
            mv -f "''${app_dir}/brain/''${uuid}" "''${bundle_dir}/brain" 2>/dev/null || true
          else
            rm -rf "''${app_dir}/brain/''${uuid}" 2>/dev/null || true
          fi
        fi

        if [[ -f "''${app_dir}/annotations/''${uuid}.pbtxt" ]]; then
          mv -f "''${app_dir}/annotations/''${uuid}.pbtxt" "''${bundle_dir}/''${uuid}.pbtxt" 2>/dev/null || true
        fi

        rm -f "''${app_dir}/presence/''${uuid}.lock" 2>/dev/null || true

        # Stamp the bundle folder with the conversation start time for 30-day retention tracking.
        touch -d "@''${start_epoch}" "$bundle_dir" 2>/dev/null || true
        log_info "Archived ''${uuid} (''${sz_kb} KiB) -> ''${bundle_dir} [reason: ''${reason}]"
        return 0
      }

      restore_conversation() {
        local app_dir="$1"
        local uuid="$2"
        local sz="$3"
        local conv_dir="''${app_dir}/conversations"
        local bundle_dir="''${app_dir}/conversations-archive/''${uuid}"

        mkdir -p "$conv_dir"
        for ext in "" "-wal" "-shm"; do
          if [[ -e "''${bundle_dir}/''${uuid}.db''${ext}" ]]; then
            mv -f "''${bundle_dir}/''${uuid}.db''${ext}" "''${conv_dir}/" 2>/dev/null || true
          fi
        done

        if [[ -d "''${bundle_dir}/brain" ]]; then
          mkdir -p "''${app_dir}/brain"
          if [[ ! -d "''${app_dir}/brain/''${uuid}" ]]; then
            mv -f "''${bundle_dir}/brain" "''${app_dir}/brain/''${uuid}" 2>/dev/null || true
          else
            rm -rf "''${bundle_dir}/brain" 2>/dev/null || true
          fi
        fi

        if [[ -f "''${bundle_dir}/''${uuid}.pbtxt" ]]; then
          mkdir -p "''${app_dir}/annotations"
          mv -f "''${bundle_dir}/''${uuid}.pbtxt" "''${app_dir}/annotations/''${uuid}.pbtxt" 2>/dev/null || true
        fi

        rmdir --ignore-fail-on-non-empty "$bundle_dir" 2>/dev/null || true
        log_info "Restored <7d user conversation ''${uuid} ($((sz / 1024)) KiB) -> ''${conv_dir}"
      }

      process_app_dir() {
        local app_dir="$1"
        local app_name="''${app_dir##*/}"
        local conv_dir="''${app_dir}/conversations"
        local archive_dir="''${app_dir}/conversations-archive"

        if [[ ! -d "$conv_dir" ]] && [[ ! -d "$archive_dir" ]]; then
          return 0
        fi

        mkdir -p "$conv_dir" "$archive_dir"
        refresh_open_paths

        local migrated_count=0
        local archived_age_count=0
        local restored_count=0
        local evicted_sub_count=0
        local evicted_user_count=0
        local purged_count=0
        local skipped_open_count=0

        USER_IDS=()
        local uid_entry
        if [[ -f "''${app_dir}/history.jsonl" ]]; then
          while IFS= read -r uid_entry; do
            [[ -n "$uid_entry" ]] && USER_IDS["$uid_entry"]=1
          done < <(jq -r '.conversationId // empty' "''${app_dir}/history.jsonl" 2>/dev/null || true)
        fi
        if [[ -f "''${app_dir}/cache/last_conversations.json" ]]; then
          while IFS= read -r uid_entry; do
            [[ -n "$uid_entry" ]] && USER_IDS["$uid_entry"]=1
          done < <(jq -r 'values[]? // empty' "''${app_dir}/cache/last_conversations.json" 2>/dev/null || true)
        fi

        # 1. Migrate legacy flat files in conversations-archive/ into per-conversation folders.
        local flat_db filename uuid start_epoch bundle_dir
        for flat_db in "''${archive_dir}"/*.db; do
          filename="''${flat_db##*/}"
          uuid="''${filename%.db}"
          if is_open_conversation "$app_dir" "$uuid" || has_live_open_handle "$uuid"; then
            log_info "[''${app_name}] Skipping flat archive migration for open conversation ''${uuid}"
            skipped_open_count=$((skipped_open_count + 1))
            continue
          fi
          bundle_dir="''${archive_dir}/''${uuid}"
          start_epoch="$(get_birth_or_mtime "$flat_db")"
          mkdir -p "$bundle_dir"

          for ext in "" "-wal" "-shm"; do
            if [[ -e "''${archive_dir}/''${uuid}.db''${ext}" ]]; then
              mv -f "''${archive_dir}/''${uuid}.db''${ext}" "''${bundle_dir}/" 2>/dev/null || true
            fi
          done

          if [[ -d "''${app_dir}/brain/''${uuid}" ]] && [[ ! -e "''${conv_dir}/''${uuid}.db" ]]; then
            if [[ ! -d "''${bundle_dir}/brain" ]]; then
              mv -f "''${app_dir}/brain/''${uuid}" "''${bundle_dir}/brain" 2>/dev/null || true
            fi
          fi

          if [[ -f "''${app_dir}/annotations/''${uuid}.pbtxt" ]] && [[ ! -e "''${conv_dir}/''${uuid}.db" ]]; then
            mv -f "''${app_dir}/annotations/''${uuid}.pbtxt" "''${bundle_dir}/''${uuid}.pbtxt" 2>/dev/null || true
          fi

          touch -d "@''${start_epoch}" "$bundle_dir" 2>/dev/null || true
          migrated_count=$((migrated_count + 1))
        done

        # Clean up any leftover flat -wal/-shm files in conversations-archive/.
        rm -f "''${archive_dir}"/*.db-wal "''${archive_dir}"/*.db-shm 2>/dev/null || true

        # 2. Archive closed conversations in conversations/ older than 7 days since last activity.
        refresh_open_paths
        local db mtime age_days
        for db in "''${conv_dir}"/*.db; do
          filename="''${db##*/}"
          uuid="''${filename%.db}"
          if is_open_conversation "$app_dir" "$uuid"; then
            skipped_open_count=$((skipped_open_count + 1))
            continue
          fi
          mtime="$(stat -c %Y "$db" 2>/dev/null || echo "$NOW")"
          if (( NOW - mtime >= ACTIVE_RETENTION_SECS )); then
            age_days=$(( (NOW - mtime) / 86400 ))
            if archive_conversation "$app_dir" "$uuid" "inactive ''${age_days}d (>=7d)"; then
              archived_age_count=$((archived_age_count + 1))
            fi
          fi
        done

        # Compute current active count/bytes and protected count/bytes (user conversations + active/<30m sub-agents).
        local active_count=0
        local active_bytes=0
        local protected_count=0
        local protected_bytes=0
        local sz
        for db in "''${conv_dir}"/*.db; do
          filename="''${db##*/}"
          uuid="''${filename%.db}"
          sz="$(stat -c %s "$db" 2>/dev/null || echo 0)"
          mtime="$(stat -c %Y "$db" 2>/dev/null || echo "$NOW")"
          active_count=$((active_count + 1))
          active_bytes=$((active_bytes + sz))
          if is_user_conversation "$app_dir" "$uuid" \
            || is_open_conversation "$app_dir" "$uuid" \
            || (( NOW - mtime < IDLE_GRACE_SECS )); then
            protected_count=$((protected_count + 1))
            protected_bytes=$((protected_bytes + sz))
          fi
        done

        # 3. Restore prematurely archived user conversations (< 7 days old) while protected set fits in budget.
        local restore_candidates
        restore_candidates="$(mktemp)"
        for uuid in "''${!USER_IDS[@]}"; do
          bundle_dir="''${archive_dir}/''${uuid}"
          db="''${bundle_dir}/''${uuid}.db"
          [[ -f "$db" ]] || continue
          [[ ! -e "''${conv_dir}/''${uuid}.db" ]] || continue

          mtime="$(stat -c %Y "$db" 2>/dev/null || echo 0)"
          if (( NOW - mtime < ACTIVE_RETENTION_SECS )); then
            sz="$(stat -c %s "$db" 2>/dev/null || echo 0)"
            printf '%s\t%s\t%s\n' "$mtime" "$sz" "$uuid" >>"$restore_candidates"
          fi
        done

        if [[ -s "$restore_candidates" ]]; then
          while IFS=$'\t' read -r mtime sz uuid; do
            if pgrep -f "wakatime-cli.*--sync-ai-activity" >/dev/null 2>&1; then
              log_warn "[''${app_name}] Stopping restore pass: wakatime-cli sync started."
              break
            fi
            if (( protected_count + 1 <= MAX_ACTIVE_FILES )) && (( protected_bytes + sz <= MAX_ACTIVE_BYTES )); then
              restore_conversation "$app_dir" "$uuid" "$sz"
              active_count=$((active_count + 1))
              active_bytes=$((active_bytes + sz))
              protected_count=$((protected_count + 1))
              protected_bytes=$((protected_bytes + sz))
              restored_count=$((restored_count + 1))
            fi
          done < <(sort -rn -k1,1 "$restore_candidates")
        fi
        rm -f "$restore_candidates"

        # 4. Enforce WakaTime ceiling: evict closed sub-agents (>30m idle) oldest-first, then user conversations.
        if (( active_count > MAX_ACTIVE_FILES )) || (( active_bytes > MAX_ACTIVE_BYTES )); then
          log_info "[''${app_name}] Active conversations exceed WakaTime budget (''${active_count}/''${MAX_ACTIVE_FILES} files, $((active_bytes / 1024 / 1024))/$((MAX_ACTIVE_BYTES / 1024 / 1024)) MiB); running eviction..."
          refresh_open_paths
          local evict_candidates
          evict_candidates="$(mktemp)"

          for db in "''${conv_dir}"/*.db; do
            filename="''${db##*/}"
            uuid="''${filename%.db}"
            if is_open_conversation "$app_dir" "$uuid"; then
              continue
            fi
            mtime="$(stat -c %Y "$db" 2>/dev/null || echo "$NOW")"
            if (( NOW - mtime < IDLE_GRACE_SECS )); then
              continue
            fi
            sz="$(stat -c %s "$db" 2>/dev/null || echo 0)"
            local tier=0
            if is_user_conversation "$app_dir" "$uuid"; then
              tier=1
            fi
            printf '%s\t%s\t%s\t%s\n' "$tier" "$mtime" "$sz" "$uuid" >>"$evict_candidates"
          done

          if [[ -s "$evict_candidates" ]]; then
            local tier label idle_mins
            while IFS=$'\t' read -r tier mtime sz uuid; do
              if (( active_count <= MAX_ACTIVE_FILES )) && (( active_bytes <= MAX_ACTIVE_BYTES )); then
                break
              fi
              idle_mins=$(( (NOW - mtime) / 60 ))
              if (( tier == 0 )); then
                label="wakatime-budget sub-agent eviction (idle ''${idle_mins}m)"
              else
                label="wakatime-budget user fallback eviction (idle ''${idle_mins}m)"
              fi
              if archive_conversation "$app_dir" "$uuid" "$label"; then
                active_count=$((active_count - 1))
                active_bytes=$((active_bytes - sz))
                if (( tier == 0 )); then
                  evicted_sub_count=$((evicted_sub_count + 1))
                else
                  evicted_user_count=$((evicted_user_count + 1))
                fi
              fi
            done < <(sort -n -k1,1 -k2,2 "$evict_candidates")
          fi
          rm -f "$evict_candidates"
        fi

        # 5. Purge archived conversation folders older than 30 days from conversation start.
        while IFS= read -r -d ''' bundle_dir; do
          uuid="''${bundle_dir##*/}"
          if [[ -f "''${bundle_dir}/''${uuid}.db" ]]; then
            start_epoch="$(get_birth_or_mtime "''${bundle_dir}/''${uuid}.db")"
          else
            start_epoch="$(stat -c %Y "$bundle_dir" 2>/dev/null || echo "$NOW")"
          fi
          if (( NOW - start_epoch > ARCHIVE_RETENTION_SECS )); then
            age_days=$(( (NOW - start_epoch) / 86400 ))
            rm -rf "$bundle_dir"
            purged_count=$((purged_count + 1))
            log_info "[''${app_name}] Purged >30d archive folder ''${uuid} (started ''${age_days}d ago)"
          fi
        done < <(find "$archive_dir" -mindepth 1 -maxdepth 1 -type d -mtime +29 -print0 2>/dev/null)

        local archive_folder_count
        archive_folder_count="$(find "$archive_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"

        log_info "[''${app_name}] Summary: active=''${active_count} files ($((active_bytes / 1024 / 1024)) MiB), archived=''${archive_folder_count} folders | migrated=''${migrated_count}, archived_7d=''${archived_age_count}, restored=''${restored_count}, evicted_sub=''${evicted_sub_count}, evicted_user=''${evicted_user_count}, purged_30d=''${purged_count}, skipped_open=''${skipped_open_count}"
      }

      log_info "Starting Antigravity conversation archival pass..."
      for app_dir in "$HOME/.gemini/antigravity-cli" "$HOME/.gemini/antigravity" "$HOME/.gemini/antigravity-ide"; do
        if [[ -d "$app_dir" ]]; then
          process_app_dir "$app_dir"
        fi
      done
      log_info "Completed Antigravity conversation archival pass."
    '';
  };
in
{
  home.packages = [ agyArchiver ];

  systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    services.agy-archiver = {
      Unit = {
        Description = "Archive inactive Antigravity conversations and prune >30d archives";
      };

      Service = {
        Type = "oneshot";
        SyslogIdentifier = "agy-archiver";
        StandardOutput = "journal";
        StandardError = "journal";
        ExecStart = "${agyArchiver}/bin/agy-archiver";
        IOSchedulingClass = "idle";
        CPUSchedulingPolicy = "idle";
      };
    };

    timers.agy-archiver = {
      Unit = {
        Description = "Hourly timer for Antigravity conversation archival";
      };

      Timer = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "5m";
      };

      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
