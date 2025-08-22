{ config, ... }:
{
  home.file = {
    "cursor-settings" = {
      target = "${config.home.homeDirectory}/.config/Cursor/User/settings.json";
      executable = false;

      text = ''
        {
          // Disable Telemetry
          "editor.experimental.treeSitterTelemetry": false,
          "telemetry.feedback.enabled": false,
          "redhat.telemetry.enabled": false,

          // Cursor General
          "cursor.general.enableShadowWorkspace": true,
          "cursor.general.gitGraphIndexing": "enabled",
          "cursor.general.disableHttp2": false,
          "cursor.general.globalCursorIgnoreList": [
            "**/.env",
            "**/.env.*",
            "**/credentials.json",
            "**/credentials.*.json",
            "**/secret.json",
            "**/secrets.json",
            "**/*.key",
            "**/*.pem",
            "**/*.pfx",
            "**/*.p12",
            "**/*.crt",
            "**/*.cer",
            "**/id_rsa",
            "**/id_dsa",
            "**/.ssh/id_*"
          ],

          // Cursor in-line code editing.
          "cursor.cmdk.autoSelect": true,
          "cursor.cmdk.useThemedDiffBackground2": true,

          // Cursor Cloud
          "cursor-retrieval.canAttemptGithubLogin": true,

          // Cursor Chat
          "cursor.chat.terminalShowHoverHint": true,
          "cursor.preferNotificationsSameAsChat": true,

          // Cursor Tab
          "cursor.cpp.disabledLanguages": [
          ],
          "cursor.cpp.enablePartialAccepts": false,

          // Cursor Composer
          "cursor.composer.cmdPFilePicker2": false,
          "cursor.composer.collapsePaneInputBoxPills": true,
          "cursor.composer.shouldAllowCustomModes": true,
          "cursor.composer.shouldAutoAcceptDiffs": true,
          "cursor.composer.shouldAutoSaveNonAgent": true,
          "cursor.composer.shouldAutoScrollToBottom": false,
          "cursor.composer.shouldChimeAfterChatFinishes": true,
          "cursor.composer.shouldQueueWhenGenerating": true,
          "cursor.composer.shouldShowMarkdownHoverParticipantActions2": true,
          "cursor.composer.showSuggestedFiles": true,

          // Cursor Diffs
          "cursor.diffs.useCharacterLevelDiffs": true,

          // Cursor Terminal
          "cursor.terminal.usePreviewBox": false,

          // Git
          "git.autofetch": true,

          // Window
          "window.commandCenter": true,
          "window.titleBarStyle": "custom",
          "window.zoomLevel": 1,
          "window.zoomPerWindow": true,

          // Editor
          "editor.colorDecorators": true,
          "editor.defaultColorDecorators": "always",
          "editor.defaultFormatter": "esbenp.prettier-vscode",
          "editor.fontFamily": "'JetBrainsMono Nerd Font', 'FiraCode Nerd Font','Noto Color Emoji', monospace",
          "editor.fontSize": 14,
          "editor.formatOnSave": true,
          "editor.minimap.enabled": true,

          // Terminal
          "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font', 'FiraCode Nerd Font', 'Noto Color Emoji', monospace",
          "terminal.integrated.fontSize": 14,

          // Workbench
          "workbench.colorTheme": "Catppuccin Mocha",
          "workbench.iconTheme": "catppuccin-mocha",

          // File Watcher excludes
          "files.watcherExclude": {
            "**/.git/objects/**": true,
            "**/.git/subtree-cache/**": true,
            "**/node_modules/*/**": true
          },

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

          // Markdown
          "[markdown]": {
            "editor.defaultFormatter": "yzhang.markdown-all-in-one",
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

          // Terraform
          "[terraform]": {
            "editor.tabSize": 2,
            "editor.insertSpaces": true,
            "editor.formatOnSave": true,
            "editor.defaultFormatter": "hashicorp.terraform"
          },
          "[terraform-vars]": {
            "editor.tabSize": 2,
            "editor.insertSpaces": true,
            "editor.formatOnSave": true,
            "editor.defaultFormatter": "hashicorp.terraform"
          },
          "terraform.languageServer.enable": true,
          "terraform.languageServer.args": [
            "serve"
          ],
          "terraform.experimentalFeatures.validateOnSave": true,
          "terraform.validation.enableEnhancedValidation": true,

          // Go
          "[go]": {
            "editor.defaultFormatter": "golang.go",
            "editor.formatOnSave": true,
            "editor.codeActionsOnSave": {
              "source.organizeImports": "always"
            }
          },
          "go.useLanguageServer": true,
          "go.formatTool": "goimports",
          "go.lintTool": "golangci-lint",

          // Shell Script
          "[shellscript]": {
            "editor.insertSpaces": false,
            "editor.tabSize": 4,
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
          },

          // Hediet DrawIO
          "hediet.vscode-drawio.appearance": "dark",
          "hediet.vscode-drawio.codeLinkActivated": false,
          "hediet.vscode-drawio.offline": false,
          "hediet.vscode-drawio.online-url": "https://embed.diagrams.net/",

          // Markdown PDF
          "markdown-pdf.format": "A4",
          "markdown-pdf.emoji": true,
          "markdown-pdf.orientation": "landscape",

          // Custom file associations.
          "files.associations": {
            ".env*": "dotenv",
            "*.mdx": "markdown"
          }

        }
      '';
    };
  };
}
