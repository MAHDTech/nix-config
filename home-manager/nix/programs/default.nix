{...}: {
  imports = [
    ./alacritty.nix
    ./ansible.nix
    ./bash.nix
    ./command-not-found.nix
    # WSL has no dbus
    #./dconf.nix
    ./direnv.nix
    ./fzf.nix
    ./git.nix
    ./gnome-keyring.nix
    ./gpg.nix
    ./htop.nix
    ./neovim.nix
    ./python.nix
    #./salt.nix
    ./sops-nix.nix
    ./ssh.nix
    ./starship.nix
    ./vim.nix
    ./vscode.nix
    ./wakatime.nix

    ./work.nix
  ];
}
