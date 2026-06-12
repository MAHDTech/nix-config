{ config, ... }:
{
  home = {
    file = {
      # 1Password SSH Agent config
      "1password-ssh-agent" = {
        target = "${config.home.homeDirectory}/.config/1Password/ssh/agent.toml";
        executable = false;
        text = ''
          # 1Password SSH agent config file
          # https://developer.1password.com/docs/ssh/agent/config
          # SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l

          # Enable all keys in the Private vault
          [[ssh-keys]]
          account = "my.1password.com"
          vault = "Private"
        '';
      };
    };
  };
}
