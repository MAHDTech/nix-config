{config, ...}: {
  home.file = {
    "1password-ssh-agent" = {
      target = "${config.home.homeDirectory}/.1Password/ssh/agent.toml";
      executable = false;

      text = ''
        # 1Password SSH agent config file
        # https://developer.1password.com/docs/ssh/agent/config
        # SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l

        # Enable all keys in the Private vault
        [[ssh-keys]]
        vault = "Private"

        # Enable JumpBox Key in the IntelliScope vault
        [[ssh-keys]]
        vault = "IntelliScope"
        item = "JumpBox SSH Key"

        # Enable GitLab Key in the IntelliScope vault
        [[ssh-keys]]
        vault = "IntelliScope"
        item = "GitLab SSH Key"
      '';
    };
  };
}
