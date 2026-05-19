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

  stdenvSystem = pkgs.stdenv.hostPlatform.system;
  litertSuffix = if stdenvSystem == "aarch64-linux" then "arm64" else "x86_64";

  litert-lm = pkgs.callPackage ../../../packages/custom/litert-lm.nix { };

  mcpServerTools = with pkgs; [
    bun
    github-mcp-server
    jq
    nodejs
    terraform-mcp-server
    uv
  ];

  # Wrap gemini-cli (nixpkgs version) + our litert-lm binary for gemma support
  gemini-cli-wrapped = pkgs.symlinkJoin {
    name = "gemini-cli";
    paths = [ pkgsUnstable.gemini-cli ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/gemini \
        --prefix PATH : ${lib.makeBinPath (mcpServerTools ++ [ litert-lm ])}
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

  sops = {
    templates = {
      # -------------------------------------------------------------------------
      # Gemini CLI settings template (containers SOPS secrets)
      # -------------------------------------------------------------------------
      "geminicli-settings-template" = {
        content = builtins.readFile ./settings.tmpl.json;
      };
    };
  };

  home = {
    file = {

      # -------------------------------------------------------------------------
      # Gemini CLI settings template
      # -------------------------------------------------------------------------
      #"geminicli-settings-template" = {
      #  target = "${config.home.homeDirectory}/.gemini/settings.tmpl.json";
      #  executable = false;
      #  source = ./settings.tmpl.json;
      #};

      # Link our Nix-packaged litert-lm binary to where gemini-cli expects it
      ".gemini/bin/litert/lit.linux_${litertSuffix}" = {
        source = lib.getExe litert-lm;
      };

    };

    # ---------------------------------------------------------------------------
    # Activation script
    # ---------------------------------------------------------------------------
    activation.mergeGeminiSettings = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix.service" ] ''
      EMAIL_PATH="${config.home.homeDirectory}/.config/sops-nix/secrets/daisyui/email"
      LICENSE_PATH="${config.home.homeDirectory}/.config/sops-nix/secrets/daisyui/license"
      TEMPLATE="${./settings.tmpl.json}"
      TARGET="$HOME/.gemini/settings.json"
      TMP_TARGET="$(mktemp)"

      # Safely load secrets from SOPS files if they exist
      EMAIL=""
      LICENSE=""
      if [ -f "$EMAIL_PATH" ]; then
        EMAIL="$(cat "$EMAIL_PATH")"
      fi
      if [ -f "$LICENSE_PATH" ]; then
        LICENSE="$(cat "$LICENSE_PATH")"
      fi

      if [ -f "$TEMPLATE" ];
      then
        if [ -f "$TARGET" ];
        then
          echo "Merging template with existing Gemini settings"
        else
          echo "Creating new Gemini settings file"
          echo "{}" > "$TARGET"
        fi
      fi

      jq \
        --slurpfile existing "$TARGET" \
        --arg email "$EMAIL" --arg license "$LICENSE" \
        'if $existing then $existing[0] * . else . end
        | .mcpServers."daisyui-blueprint".env.EMAIL = $email
        | .mcpServers."daisyui-blueprint".env.LICENSE = $license' \
        "$TEMPLATE" > "$TMP_TARGET"

      mv --force "$TMP_TARGET" "$TARGET"

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
