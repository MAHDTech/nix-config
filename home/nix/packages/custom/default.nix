{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  claude-code = pkgs.callPackage ./claude-code { };
  codex = pkgs.callPackage ./codex { };

  # Tracks upstream releases faster than nixpkgs;
  # bump with t3code/update.sh.
  # The wrapper puts the enabled agent CLIs on t3code's PATH, so they must be
  # the same builds installed elsewhere in this config.
  t3code = pkgs.callPackage ./t3code {
    # Inherit the custom pkgs
    inherit claude-code codex;
    # Inherit nixpkgs unstable
    inherit (pkgsUnstable) opencode grok-build;

    # What to enable for access from inside t3code
    enableClaude = true;
    enableCodex = true;
    enableOpencode = true;
    enableGrokBuild = true;
  };

  t3Home = "${config.home.homeDirectory}/.t3";
  t3DesktopHome = "${config.home.homeDirectory}/.t3-desktop";

  t3codePreflight = pkgs.writeShellApplication {
    name = "t3code-preflight";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
    ];
    text = ''
      mkdir -p "${t3Home}"

      if [ ! -x "${t3code}/bin/t3" ]; then
        echo "t3code-preflight: missing executable ${t3code}/bin/t3" >&2
        exit 1
      fi

      if [ ! -x "${pkgs.cloudflared}/bin/cloudflared" ]; then
        echo "t3code-preflight: missing executable ${pkgs.cloudflared}/bin/cloudflared" >&2
        exit 1
      fi

      port="''${T3CODE_PORT:-3773}"
      listeners="$(ss -Htlpn "sport = :''${port}" || true)"
      if [ -n "$listeners" ]; then
        echo "t3code-preflight: port ''${port} is already in use:" >&2
        echo "$listeners" >&2
        exit 1
      fi
    '';
  };

  t3codeWaitReady = pkgs.writeShellApplication {
    name = "t3code-wait-ready";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      port="''${T3CODE_PORT:-3773}"
      url="http://127.0.0.1:''${port}/.well-known/t3/environment"

      for _ in $(seq 1 60); do
        if [ -n "''${MAINPID:-}" ] && ! kill -0 "$MAINPID" 2>/dev/null; then
          echo "t3code-wait-ready: main process ''${MAINPID} exited before becoming ready" >&2
          exit 1
        fi

        if payload="$(curl -fsS --max-time 2 "$url" 2>/dev/null)" \
          && printf '%s' "$payload" | jq -e '.environmentId and .serverVersion' >/dev/null 2>&1; then
          exit 0
        fi

        sleep 0.5
      done

      echo "t3code-wait-ready: timed out waiting for ''${url}" >&2
      exit 1
    '';
  };

  t3codeHealthcheck = pkgs.writeShellApplication {
    name = "t3code-healthcheck";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gnugrep
      pkgs.jq
      pkgs.libnotify
      pkgs.systemd
    ];
    text = ''
      alert() {
        local message="$1"
        echo "t3code-healthcheck: ''${message}" >&2
        if [ -S "/run/user/$(id -u)/bus" ] || [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
          notify-send --app-name="T3 Code" --urgency=normal "T3 Code server health" "$message" || true
        fi
      }

      if systemctl --user is-failed --quiet t3code.service; then
        alert "t3code.service is in failed state. Check: journalctl --user -u t3code"
        exit 1
      fi

      if ! systemctl --user is-active --quiet t3code.service; then
        # Intentionally stopped; nothing to check.
        exit 0
      fi

      port="''${T3CODE_PORT:-3773}"
      url="http://127.0.0.1:''${port}/.well-known/t3/environment"

      if ! payload="$(curl -fsS --max-time 5 "$url" 2>/dev/null)"; then
        alert "HTTP endpoint unreachable on 127.0.0.1:''${port}"
        exit 1
      fi

      running_version="$(printf '%s' "$payload" | jq -r '.serverVersion // empty')"
      if [ -z "$running_version" ]; then
        alert "Invalid metadata response from ''${url}"
        exit 1
      fi

      if [ "$running_version" != "${t3code.version}" ]; then
        alert "Running v''${running_version} but installed package is v${t3code.version}. Restart t3code.service when agents are idle."
        exit 1
      fi

      status_json="$("${t3code}/bin/t3" status --json --base-dir "${t3Home}" 2>/dev/null || true)"
      if [ -n "$status_json" ]; then
        connect_revoked="$(printf '%s' "$status_json" | jq -r '.connect.revoked // false')"
        connect_enabled="$(printf '%s' "$status_json" | jq -r '.connect.enabled // false')"

        if [ "$connect_revoked" = "true" ]; then
          alert "T3 Connect credential revoked. Re-link with: t3-bootstrap --force (or t3 connect logout --base-dir ${t3Home} && t3 connect link --base-dir ${t3Home} && systemctl --user restart t3code.service)"
          exit 1
        fi

        if [ "$connect_enabled" = "true" ]; then
          connect_output="$("${t3code}/bin/t3" connect status --base-dir "${t3Home}" 2>&1 || true)"
          if printf '%s' "$connect_output" | grep -qE 'NOT reachable|removed from T3 Connect|not_authorized|dns_failed|Authorization: missing'; then
            alert "T3 Connect unhealthy. Run: t3 connect status --base-dir ${t3Home}"
            exit 1
          fi
        fi
      fi
    '';
  };

  t3Bootstrap = pkgs.writeShellApplication {
    name = "t3-bootstrap";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gnugrep
      pkgs.inetutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      # Always target the systemd service's T3CODE_HOME even if invoked from a
      # terminal spawned inside T3 Desktop (which exports T3CODE_HOME=~/.t3-desktop).
      export T3CODE_HOME="${t3Home}"

      marker="${t3Home}/.bootstrapped"
      service_env="${t3Home}/service.env"
      desktop_settings="${t3DesktopHome}/userdata/desktop-settings.json"
      force=false
      headless=false
      enable_lan=true
      status_only=false

      usage() {
        cat <<EOF
      Usage: t3-bootstrap [options]

      One-time idempotent bootstrap for t3code.service on a Linux host:
        - Ensures ${t3Home}/service.env enables LAN discovery (T3CODE_LAN=true)
        - Sets T3 Desktop to client-only mode (localEnvironmentEnabled=false)
        - Authorizes and links T3 Connect for ${t3Home}
        - Starts/restarts t3code.service and t3code-healthcheck.timer

      Re-running t3-bootstrap on an already bootstrapped host is a safe no-op
      (will not restart t3code.service or interrupt running agents).

      Options:
        --force       Re-run bootstrap and restart t3code.service
        --headless    Use URL/code OAuth flow (for SSH / headless hosts)
        --no-lan      Do not add T3CODE_LAN=true to service.env
        --status      Show bootstrap and T3 Connect status without making changes
        -h, --help    Show this help
      EOF
      }

      while [ $# -gt 0 ]; do
        case "$1" in
          --force) force=true ;;
          --headless) headless=true ;;
          --no-lan) enable_lan=false ;;
          --status) status_only=true ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            echo "t3-bootstrap: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        esac
        shift
      done

      status_json="$("${t3code}/bin/t3" status --json --base-dir "${t3Home}" 2>/dev/null || true)"
      connect_enabled="false"
      connect_revoked="false"
      if [ -n "$status_json" ]; then
        connect_enabled="$(printf '%s' "$status_json" | jq -r '.connect.enabled // false')"
        connect_revoked="$(printf '%s' "$status_json" | jq -r '.connect.revoked // false')"
      fi

      service_active=false
      if systemctl --user is-active --quiet t3code.service; then
        service_active=true
      fi

      if [ "$status_only" = true ]; then
        echo "Marker file: $([ -f "$marker" ] && echo "present ($marker)" || echo "missing")"
        echo "t3code.service: $([ "$service_active" = true ] && echo "active" || echo "inactive")"
        "${t3code}/bin/t3" connect status --base-dir "${t3Home}" || true
        exit 0
      fi

      already_bootstrapped=false
      if [ -f "$marker" ]; then
        already_bootstrapped=true
      elif [ "$connect_enabled" = "true" ] && [ "$connect_revoked" = "false" ] && [ "$service_active" = true ]; then
        already_bootstrapped=true
      fi

      if [ "$already_bootstrapped" = true ] && [ "$force" = false ]; then
        if [ "$connect_revoked" = "true" ]; then
          echo "t3-bootstrap: host was previously bootstrapped, but T3 Connect credentials are revoked." >&2
          echo "Run 't3-bootstrap --force' when agents are idle to re-authorize and restart t3code.service." >&2
          exit 1
        fi
        echo "t3-bootstrap: already bootstrapped on this host (no changes made; pass --force to re-run)."
        "${t3code}/bin/t3" connect status --base-dir "${t3Home}" || true
        exit 0
      fi

      mkdir -p "${t3Home}"

      if [ "$enable_lan" = true ]; then
        if [ ! -f "$service_env" ] || ! grep -qE '^\s*(export\s+)?T3CODE_LAN=' "$service_env"; then
          printf 'T3CODE_LAN=true\n' >> "$service_env"
          chmod 600 "$service_env"
          echo "t3-bootstrap: enabled T3CODE_LAN=true in $service_env"
        fi
      fi

      mkdir -p "$(dirname "$desktop_settings")"
      if [ -f "$desktop_settings" ] && [ -s "$desktop_settings" ] && jq -e 'type == "object"' "$desktop_settings" >/dev/null 2>&1; then
        tmp_settings="$(mktemp "$(dirname "$desktop_settings")/.desktop-settings.XXXXXX")"
        jq '.localEnvironmentEnabled = false' "$desktop_settings" > "$tmp_settings"
        mv --force "$tmp_settings" "$desktop_settings"
      else
        printf '{"localEnvironmentEnabled":false}\n' > "$desktop_settings"
      fi
      chmod 600 "$desktop_settings"
      echo "t3-bootstrap: configured T3 Desktop client-only mode ($desktop_settings)"

      unit_file="${config.xdg.configHome}/systemd/user/t3code.service"
      if [ ! -L "$unit_file" ] || [[ "$(readlink -f "$unit_file")" != /nix/store/* ]]; then
        echo "t3-bootstrap: $unit_file is not managed by Home Manager (likely overwritten by 't3 up' or 't3 connect')." >&2
        echo "Remove it (rm -f \"$unit_file\") and rebuild NixOS/Home Manager, then re-run t3-bootstrap." >&2
        exit 1
      fi

      need_link=false
      if [ "$connect_revoked" = "true" ]; then
        echo "t3-bootstrap: clearing revoked T3 Connect credential..."
        "${t3code}/bin/t3" connect logout --base-dir "${t3Home}"
        need_link=true
      elif [ "$connect_enabled" != "true" ]; then
        need_link=true
      elif [ "$force" = true ]; then
        connect_output="$("${t3code}/bin/t3" connect status --base-dir "${t3Home}" 2>&1 || true)"
        if printf '%s' "$connect_output" | grep -qE 'NOT reachable|removed from T3 Connect|not_authorized|dns_failed|Authorization: missing'; then
          echo "t3-bootstrap: resetting unhealthy T3 Connect link..."
          "${t3code}/bin/t3" connect logout --base-dir "${t3Home}"
          need_link=true
        fi
      fi

      if [ "$need_link" = true ]; then
        link_args=(connect link --base-dir "${t3Home}")
        if [ "$headless" = true ]; then
          link_args+=(--headless)
        fi
        echo "t3-bootstrap: authorizing and linking T3 Connect..."
        "${t3code}/bin/t3" "''${link_args[@]}"
      fi

      echo "t3-bootstrap: restarting t3code.service and waiting for readiness..."
      systemctl --user daemon-reload
      systemctl --user restart t3code.service
      systemctl --user start t3code-healthcheck.timer || true

      {
        printf 'bootstrapped_at=%s\n' "$(date -Iseconds)"
        printf 'host=%s\n' "$(hostname)"
        printf 'version=%s\n' "${t3code.version}"
      } > "$marker"
      chmod 600 "$marker"

      echo ""
      "${t3code}/bin/t3" connect status --base-dir "${t3Home}" || true
      echo ""
      echo "t3-bootstrap: done! Open T3 Code Desktop and sign in to T3 Connect"
      echo "(or run 't3 pair --base-dir ${t3Home}' for direct LAN pairing)."
    '';
  };

  bambuStudio =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      [ (pkgs.callPackage ./BambuStudio.nix { }) ]
    else
      [ ];

  wakatimeDesktop =
    if pkgs.stdenv.hostPlatform.isLinux then [ (pkgs.callPackage ./wakatime-desktop { }) ] else [ ];

  unstablePkgs = with pkgsUnstable; [
    codex
  ];
in
{
  home.packages = [
    #(pkgs.callPackage ./OrcaSlicer.nix { })
    #(pkgs.callPackage ./cursor.nix {})
    #(pkgs.callPackage ./tkg.nix {})
    #(pkgs.callPackage ./carvel.nix {})
    #(pkgs.callPackage ./kpack.nix {})
    #(pkgs.callPackage ./pivnet.nix {})
    #(pkgs.callPackage ./litert-lm.nix {})
    (pkgs.callPackage ./antigravity-cli { })
    (pkgs.callPackage ./antigravity-hub { })
    claude-code
    codex
    t3code
    #(pkgs.callPackage ./ls-colors.nix { })
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ t3Bootstrap ]
  ++ bambuStudio
  ++ wakatimeDesktop
  ++ unstablePkgs;
  systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    services.t3code = {
      Unit = {
        Description = "T3 Code server";
        After = [ "network.target" ];
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };

      Service = {
        ExecStartPre = lib.getExe t3codePreflight;
        ExecStart = "${t3code}/bin/t3 serve --base-dir ${t3Home}";
        ExecStartPost = lib.getExe t3codeWaitReady;
        WorkingDirectory = config.home.homeDirectory;
        Environment = [
          "T3CODE_HOME=${t3Home}"
          "PATH=${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin"
        ];
        EnvironmentFile = "-${t3Home}/service.env";
        Restart = "on-failure";
        RestartSec = 5;
        KillMode = "mixed";
        # Keep the server alive if an agent child process hits OOM.
        OOMPolicy = "continue";
        CPUWeight = 1000;
        IOWeight = 1000;
        MemoryLow = "1536M";
        ManagedOOMPreference = "avoid";
        TimeoutStartSec = 45;
        TimeoutStopSec = 30;
        # t3 serve exits with 130 (SIGINT) / 143 (SIGTERM) on clean shutdown.
        SuccessExitStatus = [
          130
          143
        ];
      };

      Install.WantedBy = [ "default.target" ];
    };

    services.t3code-healthcheck = {
      Unit = {
        Description = "T3 Code server health check (alert-only)";
        After = [ "t3code.service" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe t3codeHealthcheck;
        Environment = [
          "T3CODE_HOME=${t3Home}"
        ];
        EnvironmentFile = "-${t3Home}/service.env";
      };
    };

    timers.t3code-healthcheck = {
      Unit.Description = "Periodic T3 Code server health check";

      Timer = {
        OnBootSec = "2m";
        OnUnitActiveSec = "15m";
        Unit = "t3code-healthcheck.service";
      };

      Install.WantedBy = [ "timers.target" ];
    };
  };

  # On fresh Linux hosts, default T3 Desktop to client-only mode so it does not
  # spawn a second embedded server + T3 Connect tunnel alongside t3code.service.
  # Only seeds when missing so existing settings and Electron window state stay
  # untouched and writable.
  home.activation.seedT3DesktopSettings = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      t3_desktop_settings="${t3DesktopHome}/userdata/desktop-settings.json"
      if [ ! -e "$t3_desktop_settings" ]; then
        mkdir -p "$(dirname "$t3_desktop_settings")"
        printf '{"localEnvironmentEnabled":false}\n' > "$t3_desktop_settings"
        chmod 600 "$t3_desktop_settings"
      fi
    ''
  );
}
