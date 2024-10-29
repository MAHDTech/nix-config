{config, ...}: {
  home.file = {
    "cursor-settings" = {
      target = "${config.home.homeDirectory}/.config/Cursor/User/settings.json";
      executable = false;

      text = ''
        {
          // Window
          "window.commandCenter": true,
          "window.zoomLevel": 1,

          // Editor
          "editor.fontFamily": "'JetBrains Mono', 'JetBrains Mono Nerd Font', monospace",
          "editor.fontSize": 14,
          "editor.minimap.enabled": true,

          // Terminal
          "terminal.integrated.fontFamily": "'Ubuntu Mono', 'JetBrains Mono', 'JetBrains Mono Nerd Font', monospace",
          "terminal.integrated.fontSize": 14
        }
      '';
    };
  };
}
