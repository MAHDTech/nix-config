{ inputs, config, lib, pkgs, ... }:

{

  # Define imports
  imports = [

    # Home Manager
    ./imports/home-manager.nix

    # XDG user directories
    ./imports/user-dirs.nix

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

    # Files
    ./imports/files.nix

    # Fuzzy Finder
    ./imports/fzf.nix

    # GNOME Keyring
    ./imports/gnome-keyring.nix

    # GPG
    ./imports/gpg.nix

    # SSH
    ./imports/ssh.nix

    # Smart Cards
    ./imports/smartcards.nix

    # Starship
    ./imports/starship.nix

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

    # Work stuff
    ./imports/work.nix

    # Custom scripts
    #./imports/scripts.nix

    # Custom derivations.
    ./derivations

  ];

}
