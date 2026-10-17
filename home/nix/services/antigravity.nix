{ lib, pkgs, ... }:
let
  archiveConversations = pkgs.writeShellApplication {
    name = "agy-archive-conversations";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gawk
      gnugrep
      jq
      util-linux
    ];
    text = ''
      shopt -s nullglob

      LOCK_FILE="''${XDG_RUNTIME_DIR:-/tmp}/agy-archive-conversations.lock"
      exec 9>"$LOCK_FILE"
      flock -n 9 || exit 0

      NOW="$(date +%s)"
      IDLE_GRACE_SECS=$((30 * 60))
      ACTIVE_RETENTION_SECS=$((7 * 86400))
      ARCHIVE_RETENTION_SECS=$((30 * 86400))

      # wakatime-cli scans every .db in conversations/ on each sync with a 256 MiB / 5s limit.
      # Metadata columns are ~16% of file size, so 1 GiB of .db files stays well under 256 MiB.
      MAX_ACTIVE_BYTES=$((1024 * 1024 * 1024))
      MAX_ACTIVE_FILES=150

      OPEN_PATHS="$(readlink /proc/[0-9]*/fd/* 2>/dev/null | grep -F '/.gemini/' || true)"

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

      is_user_conversation() {
        local app_dir="$1"
        local uuid="$2"
        local user_ids_file="$3"

        if grep -Fqx "$uuid" "$user_ids_file" 2>/dev/null; then
          return 0
        fi
        if [[ -f "''${app_dir}/annotations/''${uuid}.pbtxt" ]] || [[ -f "''${app_dir}/conversations-archive/''${uuid}/''${uuid}.pbtxt" ]]; then
          return 0
        fi

        local transcript=""
        if [[ -f "''${app_dir}/brain/''${uuid}/.system_generated/logs/transcript.jsonl" ]]; then
          transcript="''${app_dir}/brain/''${uuid}/.system_generated/logs/transcript.jsonl"
        elif [[ -f "''${app_dir}/conversations-archive/''${uuid}/brain/.system_generated/logs/transcript.jsonl" ]]; then
          transcript="''${app_dir}/conversations-archive/''${uuid}/brain/.system_generated/logs/transcript.jsonl"
        fi

        if [[ -n "$transcript" ]] && head -n 1 "$transcript" 2>/dev/null | grep -Fq '"USER_EXPLICIT"'; then
          return 0
        fi

        return 1
      }

      archive_conversation() {
        local app_dir="$1"
        local uuid="$2"
        local conv_dir="''${app_dir}/conversations"
        local bundle_dir="''${app_dir}/conversations-archive/''${uuid}"
        local db="''${conv_dir}/''${uuid}.db"
        local start_epoch="$NOW"

        if [[ -e "$db" ]]; then
          start_epoch="$(get_birth_or_mtime "$db")"
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
      }

      restore_conversation() {
        local app_dir="$1"
        local uuid="$2"
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
      }

      process_app_dir() {
        local app_dir="$1"
        local conv_dir="''${app_dir}/conversations"
        local archive_dir="''${app_dir}/conversations-archive"

        if [[ ! -d "$conv_dir" ]] && [[ ! -d "$archive_dir" ]]; then
          return 0
        fi

        mkdir -p "$conv_dir" "$archive_dir"

        local user_ids_file
        user_ids_file="$(mktemp)"

        if [[ -f "''${app_dir}/history.jsonl" ]]; then
          jq -r '.conversationId // empty' "''${app_dir}/history.jsonl" 2>/dev/null >>"$user_ids_file" || true
        fi
        if [[ -f "''${app_dir}/cache/last_conversations.json" ]]; then
          jq -r 'values[]? // empty' "''${app_dir}/cache/last_conversations.json" 2>/dev/null >>"$user_ids_file" || true
        fi
        sort -u -o "$user_ids_file" "$user_ids_file"

        # 1. Migrate legacy flat files in conversations-archive/ into per-conversation folders.
        local flat_db filename uuid start_epoch bundle_dir
        for flat_db in "''${archive_dir}"/*.db; do
          filename="''${flat_db##*/}"
          uuid="''${filename%.db}"
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
        done

        # Clean up any leftover flat -wal/-shm files in conversations-archive/.
        rm -f "''${archive_dir}"/*.db-wal "''${archive_dir}"/*.db-shm 2>/dev/null || true

        # 2. Archive closed conversations in conversations/ older than 7 days since last activity.
        local db mtime
        for db in "''${conv_dir}"/*.db; do
          filename="''${db##*/}"
          uuid="''${filename%.db}"
          if is_open_conversation "$app_dir" "$uuid"; then
            continue
          fi
          mtime="$(stat -c %Y "$db" 2>/dev/null || echo "$NOW")"
          if (( NOW - mtime >= ACTIVE_RETENTION_SECS )); then
            archive_conversation "$app_dir" "$uuid"
          fi
        done

        # Compute current active count and cumulative byte size.
        local active_count=0
        local active_bytes=0
        local sz
        for db in "''${conv_dir}"/*.db; do
          sz="$(stat -c %s "$db" 2>/dev/null || echo 0)"
          active_count=$((active_count + 1))
          active_bytes=$((active_bytes + sz))
        done

        # 3. Restore prematurely archived user conversations (< 7 days old) while under budget.
        local restore_candidates
        restore_candidates="$(mktemp)"
        for bundle_dir in "''${archive_dir}"/*/; do
          bundle_dir="''${bundle_dir%/}"
          uuid="''${bundle_dir##*/}"
          db="''${bundle_dir}/''${uuid}.db"
          [[ -f "$db" ]] || continue
          [[ ! -e "''${conv_dir}/''${uuid}.db" ]] || continue

          mtime="$(stat -c %Y "$db" 2>/dev/null || echo 0)"
          if (( NOW - mtime < ACTIVE_RETENTION_SECS )) && is_user_conversation "$app_dir" "$uuid" "$user_ids_file"; then
            sz="$(stat -c %s "$db" 2>/dev/null || echo 0)"
            printf '%s\t%s\t%s\n' "$mtime" "$sz" "$uuid" >>"$restore_candidates"
          fi
        done

        if [[ -s "$restore_candidates" ]]; then
          while IFS=$'\t' read -r mtime sz uuid; do
            if (( active_count + 1 <= MAX_ACTIVE_FILES )) && (( active_bytes + sz <= MAX_ACTIVE_BYTES )); then
              restore_conversation "$app_dir" "$uuid"
              active_count=$((active_count + 1))
              active_bytes=$((active_bytes + sz))
            fi
          done < <(sort -rn -k1,1 "$restore_candidates")
        fi
        rm -f "$restore_candidates"

        # 4. Enforce WakaTime ceiling: evict closed sub-agents (>30m idle) oldest-first, then user conversations.
        if (( active_count > MAX_ACTIVE_FILES )) || (( active_bytes > MAX_ACTIVE_BYTES )); then
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
            if is_user_conversation "$app_dir" "$uuid" "$user_ids_file"; then
              tier=1
            fi
            printf '%s\t%s\t%s\t%s\n' "$tier" "$mtime" "$sz" "$uuid" >>"$evict_candidates"
          done

          if [[ -s "$evict_candidates" ]]; then
            local tier
            while IFS=$'\t' read -r tier mtime sz uuid; do
              if (( active_count <= MAX_ACTIVE_FILES )) && (( active_bytes <= MAX_ACTIVE_BYTES )); then
                break
              fi
              archive_conversation "$app_dir" "$uuid"
              active_count=$((active_count - 1))
              active_bytes=$((active_bytes - sz))
            done < <(sort -n -k1,1 -k2,2 "$evict_candidates")
          fi
          rm -f "$evict_candidates"
        fi

        # 5. Purge archived conversation folders older than 30 days from conversation start.
        for bundle_dir in "''${archive_dir}"/*/; do
          bundle_dir="''${bundle_dir%/}"
          [[ -d "$bundle_dir" ]] || continue
          uuid="''${bundle_dir##*/}"
          if [[ -f "''${bundle_dir}/''${uuid}.db" ]]; then
            start_epoch="$(get_birth_or_mtime "''${bundle_dir}/''${uuid}.db")"
          else
            start_epoch="$(stat -c %Y "$bundle_dir" 2>/dev/null || echo "$NOW")"
          fi
          if (( NOW - start_epoch > ARCHIVE_RETENTION_SECS )); then
            rm -rf "$bundle_dir"
          fi
        done

        rm -f "$user_ids_file"
      }

      for app_dir in "$HOME/.gemini/antigravity-cli" "$HOME/.gemini/antigravity" "$HOME/.gemini/antigravity-ide"; do
        if [[ -d "$app_dir" ]]; then
          process_app_dir "$app_dir"
        fi
      done
    '';
  };
in
{
  home.packages = [ archiveConversations ];

  systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    services.agy-archive-conversations = {
      Unit = {
        Description = "Archive inactive Antigravity conversations and prune >30d archives";
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${archiveConversations}/bin/agy-archive-conversations";
        IOSchedulingClass = "idle";
        CPUSchedulingPolicy = "idle";
      };
    };

    timers.agy-archive-conversations = {
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
