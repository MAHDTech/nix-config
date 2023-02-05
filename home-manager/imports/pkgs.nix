{ config, lib, pkgs, ... }:

##################################################
# Name: pkgs.nix
# Description: Package management
##################################################

{

  nixpkgs.config = {

    allowUnfree = true ;
    allowBroken = false ;

  };

  home.packages = with pkgs; [

    # AWS
    #awscli

    # Azure
    #azure-cli
    #azure-storage-azcopy

    # Google Cloud
    #google-cloud-sdk

    # VMWare

    # CLI utilities
    bat
    binutils
    bottom
    bzip2
    coreutils
    curl
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
    ncdu
    neofetch
    nushell
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
    wakatime
    wget
    wsl-open
    xdg-user-dirs
    xdg-utils
    xdotool
    xsv
    xxd
    youtube-dl
    zip

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
    gtk3
    inkscape
    librsvg
    locale
    logseq

  ];

}

