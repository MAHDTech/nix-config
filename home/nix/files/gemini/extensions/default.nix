{ config, ... }:

{
  home = {
    file = {
      # -------------------------------------------------------------------------
      # Gemini CLI extension manager script
      # -------------------------------------------------------------------------
      "geminicli-extensions" = {
        target = "${config.home.homeDirectory}/.local/bin/gemini-extensions";
        executable = true;
        source = ./gemini-extensions.sh;
      };
    };
  };
}
