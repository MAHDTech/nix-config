{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let

  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
  };

  mcpServerTools = with pkgs; [
    bun
    github-mcp-server
    jq
    nodejs
    terraform-mcp-server
    uv
  ];

  # Wrap gemini-cli so it has the mcpServers in its PATH
  gemini-cli-wrapped = pkgs.symlinkJoin {
    name = "gemini-cli";
    paths = [ pkgsUnstable.gemini-cli ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/gemini \
        --prefix PATH : ${lib.makeBinPath mcpServerTools}
    '';
  };

in
{
  # ---------------------------------------------------------------------------
  # Gemini CLI
  #
  # ~/.gemini/settings.tmpl.json  — Nix-managed template (read-only)
  # ~/.gemini/settings.json       — writable file owned by the CLI
  #
  # On every `home-manager switch` / `nixos-rebuild switch`, the activation
  # script deep-merges the template INTO the live settings file using jq:
  #
  #   jq -s '.[0] * .[1]' existing.json template.json > settings.json
  #
  # - The template wins for any key it explicitly defines.
  # - Any extra keys written by the CLI are left untouched.
  # ---------------------------------------------------------------------------

  home = {
    file = {

      # -------------------------------------------------------------------------
      # Gemini CLI settings template
      # -------------------------------------------------------------------------
      "geminicli-settings-template" = {
        target = "${config.home.homeDirectory}/.gemini/settings.tmpl.json";
        executable = false;
        source = ./settings.tmpl.json;
      };

      # -------------------------------------------------------------------------
      # Pickle Rick God Mode policies
      # -------------------------------------------------------------------------
      "geminicli-policy-allowed" = {
        target = "${config.home.homeDirectory}/.gemini/policies/pickle_rick.toml";
        executable = false;
        source = ./pickle_rick.toml;
      };

    };

    # ---------------------------------------------------------------------------
    # Activation script
    # ---------------------------------------------------------------------------
    activation.mergeGeminiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      TEMPLATE="$HOME/.gemini/settings.tmpl.json"
      TARGET="$HOME/.gemini/settings.json"
      TMP_TARGET="$(mktemp)"

      if [ -f "$TARGET" ]; then
        # Deep-merge: existing keys are base, template keys win for overlapping paths.
        # This enforces your declarative defaults while preserving CLI-managed keys
        # (e.g. auth tokens, cached state inside nested objects).
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$TARGET" "$TEMPLATE" > "$TMP_TARGET"
        mv --force "$TMP_TARGET" "$TARGET"
      else
        cp --force "$TEMPLATE" "$TARGET"
      fi

      chmod 600 "$TARGET"
    '';

    packages =
      with pkgs;
      [
        jq # JSON parser
        nodejs # gemini-cli-security extension
        gemini-cli-wrapped
      ]
      ++ mcpServerTools;
  };
}
