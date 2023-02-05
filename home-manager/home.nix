{ config, lib, pkgs, ... }:

{

  # Define imports
  imports = [

    # Home Manager
    ./imports/home-manager.nix

    # User
    ./imports/user.nix

    # Common
    ./imports/common.nix

    # Global package config
    ./imports/pkgs.nix

    # Systemd
    ./imports/systemd.nix

    # Bash
    ./imports/bash.nix

    # Fonts
    ./imports/fonts.nix

    # Fuzzy Finder
    ./imports/fzf.nix

    # TODO: Fix Docker
    # Virtualisation and Containers
    #./imports/virtualisation.nix

    # GNOME Keyring
    ./imports/gnome-keyring.nix

    # GPG
    ./imports/gpg.nix

    # SSH
    ./imports/ssh.nix

    # Smart Cards
    ./imports/smartcards.nix

    # Git
    # TODO: Finish git
    ./imports/git.nix

    # Ansible
    ./imports/ansible.nix

    # htop
    ./imports/htop.nix

    # VSCode extension management
    ./imports/vscode.nix

    # Vim plugin management
    ./imports/vim.nix

    # XDG user directories
    ./imports/user-dirs.nix

    # Custom scripts
    #./imports/scripts.nix

    # TODO: Finish backup
    # ./imports/backup.nix

    # Custom derivations

    # ls-colors
    #./derivations/ls-colors.nix

  ];

}
