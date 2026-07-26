{
  config,
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  grokPkg =
    if pkgsUnstable ? grok-build then
      [ pkgsUnstable.grok-build ]
    else if pkgs ? grok-build then
      [ pkgs.grok-build ]
    else
      [ ];
in
{
  # ---------------------------------------------------------------------------
  # Grok Build (xAI CLI AI tool) Configuration
  # ---------------------------------------------------------------------------
  home = {
    file = {
      # Grok Build Settings Template
      "grok-build-settings-template" = {
        target = "${config.home.homeDirectory}/.grok/config.tmpl.toml";
        executable = false;
        text = ''
          [models]
          default = "grok-build"
          web_search = "grok-4.5"

          [cli]
          auto_update = false

          [permission]
          allow = [
            "Bash(devenv *)",
            "Bash(nix *)",
            "MCPTool(tars__*)"
          ]

          [mcp_servers.devenv]
          command = "${pkgsUnstable.devenv}/bin/devenv"
          args = ["mcp"]
          enabled = true

          [mcp_servers.github]
          command = "${config.home.homeDirectory}/.local/bin/github-mcp-server-start"
          args = ["stdio"]
          enabled = true

          [mcp_servers.terraform]
          command = "${config.home.homeDirectory}/.local/bin/terraform-mcp-server-start"
          args = []
          enabled = true

          [mcp_servers.opentofu]
          command = "${config.home.homeDirectory}/.local/bin/opentofu-mcp-server-start"
          args = []
          enabled = true

          [mcp_servers.nixos]
          command = "${config.home.homeDirectory}/.local/bin/mcp-nixos-start"
          args = []
          enabled = true

          [mcp_servers.daisyui]
          command = "${config.home.homeDirectory}/.local/bin/daisyui-mcp-server-start"
          args = []
          enabled = true
        '';
      };
    };

    # ---------------------------------------------------------------------------
    # Activation script: Deep Merge TOML (Template merged into target)
    # ---------------------------------------------------------------------------
    activation.mergeGrokSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      merge_toml() {
        local target="$1"
        local tmpl="$2"
        local tmp_target="$(mktemp)"

        mkdir -p "$(dirname "$target")"

        if [ -f "$target" ] && [ -s "$target" ] && ${pkgs.yq-go}/bin/yq eval -p=toml -o=toml '.' "$target" >/dev/null 2>&1; then
          ${pkgs.yq-go}/bin/yq eval-all -p=toml -o=toml '. as $item ireduce ({}; . * $item)' "$target" "$tmpl" > "$tmp_target"
          mv --force "$tmp_target" "$target"
        else
          cp --force "$tmpl" "$target"
          rm -f "$tmp_target"
        fi
        chmod 600 "$target"
      }

      merge_toml "$HOME/.grok/config.toml" "$HOME/.grok/config.tmpl.toml"
    '';

    packages =
      grokPkg
      ++ (with pkgs; [
        jq
        yq-go
        github-mcp-server
      ]);
  };
}
