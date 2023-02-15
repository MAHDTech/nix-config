{ config, lib, pkgs, ... }:

##################################################
# Name: pkgs.nix
# Description: Package management
##################################################

{

  home.packages = with pkgs; [

    # AWS
    #awscli

    # Azure
    #azure-cli
    #azure-storage-azcopy

    # Google Cloud
    #google-cloud-sdk

    # CLI utilities
    alejandra
    bat
    binutils
    bottom
    bzip2
    coreutils
    #curl
    curlFull
    dos2unix
    edid-decode
    exa
    fd
    figlet
    file
    fortune
    htop
    inetutils
    jq
    kubectl
    libcap
    lolcat
    mkpasswd
    ncdu
    neofetch
    nushell
    nixpkgs-fmt
    rnix-lsp
    openssh
    packer
    pandoc
    pciutils
    powershell
    pulumi-bin
    puppeteer-cli
    rclone
    read-edid
    restic
    ripgrep
    rsync
    salt
    shadow
    shellcheck
    sops
    starship
    terraform
    terraform-docs
    terraform-ls
    tflint
    tfsec
    tokei
    tree
    unzip
    usbutils
    wget
    wsl-open
    xdg-user-dirs
    xdg-utils
    xdotool
    xsv
    xxd
    youtube-dl
    zip
    wally-cli

    # Office
    libreoffice

    # Development
    cmake
    gcc
    gdb
    glib
    glibc
    gnumake
    gnupatch
    go
    gofumpt
    golangci-lint
    golint
    graphviz
    haskellPackages.hadolint
    haskellPackages.language-docker
    hidapi
    hugo
    nodejs-16_x
    pkgconfig
    python3
    python3Packages.pip
    rust-analyzer
    rustup
    texlive.combined.scheme-full
    wakatime
    zsa-udev-rules

    # Font management
    font-manager

    # GUI
    brave
    gtk3
    inkscape
    librsvg
    locale
    logseq
    _1password
    _1password-gui

  ];

}
