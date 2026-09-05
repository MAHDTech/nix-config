{
  config,
  pkgs,
  ...
}:
let
  scriptName = "agy-install-plugins";
  scriptPath = "${config.home.homeDirectory}/.local/bin/${scriptName}";
in
{
  home = {
    packages = with pkgs; [
      git
      jq
    ];

    file = {
      ${scriptName} = {
        target = ".local/bin/${scriptName}";
        executable = true;

        text = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          PLUGIN_DIR="''${HOME}/.gemini/config/plugins"
          IMPORT_MANIFEST="''${HOME}/.gemini/config/import_manifest.json"

          # List of desired plugins (Git URLs, local directories, or name@marketplace)
          PLUGINS=(
            "https://github.com/wakatime/antigravity-cli-wakatime"
          )

          if ! command -v agy >/dev/null 2>&1; then
            echo "Error: 'agy' (Antigravity CLI) not found in PATH" >&2
            exit 1
          fi

          # Extract a normalized plugin name from a target specification
          get_plugin_name() {
            local target="$1"
            if [[ "$target" =~ ^https?:// ]] || [[ "$target" =~ \.git$ ]]; then
              ${pkgs.coreutils}/bin/basename "$target" .git
            elif [[ "$target" =~ @ ]]; then
              echo "$target" | ${pkgs.coreutils}/bin/cut -d'@' -f1
            elif [[ -d "$target" && -f "$target/plugin.json" ]]; then
              ${pkgs.jq}/bin/jq -r '.name // empty' "$target/plugin.json" 2>/dev/null || ${pkgs.coreutils}/bin/basename "$target"
            else
              ${pkgs.coreutils}/bin/basename "$target"
            fi
          }

          # Check if a plugin is installed
          is_plugin_installed() {
            local name="$1"

            # Check filesystem location
            if [[ -d "''${PLUGIN_DIR}/''${name}" && -f "''${PLUGIN_DIR}/''${name}/plugin.json" ]]; then
              return 0
            fi

            # Check agy plugin list / import manifest
            if [[ -f "$IMPORT_MANIFEST" ]]; then
              if ${pkgs.jq}/bin/jq -e --arg n "$name" '.imports[]? | select(.name == $n)' "$IMPORT_MANIFEST" >/dev/null 2>&1; then
                return 0
              fi
            fi

            return 1
          }

          # Main installer logic
          install_plugins() {
            local do_update="''${1:-false}"

            echo "==> Checking Antigravity CLI plugins..."
            ${pkgs.coreutils}/bin/mkdir -p "$PLUGIN_DIR"

            for target in "''${PLUGINS[@]}"; do
              local name
              name=$(get_plugin_name "$target")

              if is_plugin_installed "$name"; then
                if [ "$do_update" = true ]; then
                  if [ -d "''${PLUGIN_DIR}/''${name}/.git" ]; then
                    echo "[-] Updating ''${name} via git pull..."
                    ${pkgs.git}/bin/git -C "''${PLUGIN_DIR}/''${name}" pull --ff-only || echo "    [!] Warning: Failed to git pull ''${name}"
                  else
                    echo "[-] Re-installing ''${name} to update..."
                    agy plugin install "$target"
                  fi
                else
                  echo "  [✓] ''${name} is already installed (skipped)"
                fi
              else
                echo "[+] Installing ''${name} from ''${target}..."
                if agy plugin install "$target"; then
                  agy plugin enable "$name" >/dev/null 2>&1 || true
                  echo "  [✓] Successfully installed and enabled ''${name}"
                else
                  echo "  [✗] Failed to install ''${name}" >&2
                fi
              fi
            done

            echo "==> Done. Current plugins:"
            agy plugin list
          }

          # Parse CLI flags
          UPDATE=false
          while [[ $# -gt 0 ]]; do
            case "$1" in
              -u|--update)
                UPDATE=true
                shift
                ;;
              -l|--list)
                agy plugin list
                exit 0
                ;;
              -h|--help)
                echo "Usage: $(basename "$0") [OPTIONS]"
                echo "Options:"
                echo "  -u, --update  Update already-installed git plugins to latest"
                echo "  -l, --list    List currently installed plugins"
                echo "  -h, --help    Show this help message"
                exit 0
                ;;
              *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
            esac
          done

          install_plugins "$UPDATE"
        '';
      };
    };

    sessionVariables = {
      AGY_INSTALL_PLUGINS = scriptPath;
    };
  };
}
