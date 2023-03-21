{config, ...}: {
  home.file = {
    "cargo-config" = {
      target = "${config.home.homeDirectory}/.cargo/config";
      executable = false;

      text = ''
        [net]
        git-fetch-with-cli = true
      '';
    };
  };
}
