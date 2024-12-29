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
          "window.titleBarStyle": "custom",

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
          "editor.codeActionsOnSave": {
            "source.fixAll.eslint": "always"
          },
          "eslint.format.enable": true,
          "eslint.validate": [
            "javascript",
            "javascriptreact",
            "astro",
            "typescript",
            "typescriptreact"
          ],

          // Prettier
          "prettier.documentSelectors": ["**/*.astro"],

          /*
          Language based settings
          */

          // Astro
          "[astro]": {
            "editor.defaultFormatter": "astro-build.astro-vscode"
          },

          // Javascript
          "[javascript]": {
            "editor.defaultFormatter": "dbaeumer.vscode-eslint"
          },

          // Typescript
          "typescript.inlayHints.parameterNames.enabled": "all",
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

          // Go
          "[go]": {
            "editor.defaultFormatter": "golang.go",
            "editor.formatOnSave": true,
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
