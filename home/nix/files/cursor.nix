{config, ...}: {
  home.file = {
    "cursor-settings" = {
      target = "${config.home.homeDirectory}/.config/Cursor/User/settings.json";
      executable = false;

      text = ''
        {
          // Cursor
          "cursor.chat.alwaysSearchWeb": true,
          "cursor.chat.defaultNoContext": false,
          "cursor.chat.premiumChatAutoScrollWhenAtBottom": false,
          "cursor.chat.showSuggestedFiles": true,
          "cursor.chat.smoothStreaming": true,

          // Window
          "window.commandCenter": true,
          "window.zoomLevel": 1,

          // Editor
          "editor.fontFamily": "'JetBrains Mono', 'JetBrains Mono Nerd Font', monospace",
          "editor.fontSize": 14,
          "editor.minimap.enabled": true,

          // Terminal
          "terminal.integrated.fontFamily": "'Ubuntu Mono', 'JetBrains Mono', 'JetBrains Mono Nerd Font', monospace",
          "terminal.integrated.fontSize": 14,

          // Workbench
          "workbench.colorTheme": "Catppuccin Mocha",
          "workbench.iconTheme": "catppuccin-mocha"
        }
      '';
    };
  };
}
