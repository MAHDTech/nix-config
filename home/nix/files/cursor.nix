{config, ...}: {
  home.file = {
    "cursor-settings" = {
      target = "${config.home.homeDirectory}/.config/Cursor/User/settings.json";
      executable = false;

      text = ''
        {
          // Cursor General
          "cursor.general.enableShadowWorkspace": true,
          "cursor.general.gitGraphIndexing": "enabled",

          // Cursor Cloud
          "cursor-retrieval.canAttemptGithubLogin": true,

          // Cursor Chat
          "cursor.chat.alwaysSearchWeb": false,
          "cursor.chat.defaultNoContext": false,
          "cursor.chat.premiumChatAutoScrollWhenAtBottom": false,
          "cursor.chat.showSuggestedFiles": true,
          "cursor.chat.smoothStreaming": true,

          // Cursor Composer
          "cursor.composer.collapsePaneInputBoxPills": true,

          // Cursor Diffs
          "cursor.cmdk.useThemedDiffBackground": true,
          "cursor.diffs.useCharacterLevelDiffs": true,

          // Cursor AI Preview
          "cursor.aipreview.enabled": true,

          // Window
          "window.commandCenter": true,
          "window.zoomLevel": 1,

          // Editor
          "editor.fontFamily": "'JetBrains Mono', 'JetBrains Mono Nerd Font', monospace",
          "editor.fontSize": 14,
          "editor.minimap.enabled": true,
          "editor.defaultFormatter": "esbenp.prettier-vscode",
          "editor.formatOnSave": true,

          // Terminal
          "terminal.integrated.fontFamily": "'Ubuntu Mono', 'JetBrains Mono', 'JetBrains Mono Nerd Font', monospace",
          "terminal.integrated.fontSize": 14,

          // Workbench
          "workbench.colorTheme": "Catppuccin Mocha",
          "workbench.iconTheme": "catppuccin-mocha",

          /*
          Linters
          */

          // ESLint
          "eslint.format.enable": true,
          "editor.codeActionsOnSave": {
            "source.fixAll.eslint": "always"
          },

          /*
          Language based settings
          */

          // Javascript
          "[javascript]": {
            "editor.defaultFormatter": "dbaeumer.vscode-eslint"
          },

          // Typescript
          "[typescript]": {
            "editor.defaultFormatter": "dbaeumer.vscode-eslint"
          },

          // JSON
          "[json]": {
            "editor.defaultFormatter": "esbenp.prettier-vscode",
            "editor.tabSize": 2
          },

          // Rust
          "[rust]": {
            "editor.defaultFormatter": "rust-lang.rust-analyzer"
          },

          // YAML
          "[yaml]": {
            "editor.insertSpaces": true,
            "editor.tabSize": 2,
            "editor.autoIndent": "advanced",
            "diffEditor.ignoreTrimWhitespace": false,
            "editor.defaultFormatter": "esbenp.prettier-vscode"
          },

          // GitHub Actions
          "[github-actions-workflow]": {
            "editor.insertSpaces": true,
            "editor.tabSize": 2
          }
        }
      '';
    };
  };
}
