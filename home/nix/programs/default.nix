{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./ansible.nix
    ./bash.nix
    ./command-not-found.nix
    ./direnv.nix
    ./fzf.nix
    ./git.nix
    ./gnome-keyring.nix
    ./gpg.nix
    ./htop.nix
    ./neovim.nix
    ./python.nix
    ./salt.nix
    ./ssh.nix
    ./starship.nix
    ./vim.nix
    ./vscode.nix
    ./wakatime.nix

    ./work.nix
  ];
}
