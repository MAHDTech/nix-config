{
  programs.direnv = {
    enable = true;
    silent = false;
    enableBashIntegration = true;

    nix-direnv = {
      enable = true;
    };

    config = {
      disable_stdin = false;
      load_dotenv = false;
      strict_env = false;
      warn_timeout = "10s";
    };
  };
}
