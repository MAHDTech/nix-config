{pkgs, ...}: {
  home.packages = with pkgs; [
    # Password Manager
    _1password-gui
    _1password-cli

    # File management
    insync
    restic
    rclone
    rsync

    # Nix
    nixos-generators
    nix-du

    # Shell
    nushell

    # File Systems
    btrfs-progs
    cryptsetup
    dosfstools
    exfat
    gptfdisk
    lvm2
    mdadm
    parted
    ntfs3g
    xfsprogs

    # Disk imagers
    unetbootin
    ventoy-full

    # CLI
    bat
    bottom
    charasay
    curlFull
    complete-alias
    dos2unix
    edid-decode
    eza
    fd
    figlet
    file
    fortune
    gptfdisk
    hello
    htop
    jq
    libcap
    lolcat
    ncdu
    neofetch
    pandoc
    pciutils
    read-edid
    ripgrep
    shadow
    shellcheck
    socat
    sops
    tailscale
    tokei
    tree
    unzip
    usbutils
    which
    wget
    xdotool
    xsv
    xxd
    zip

    # Terminal
    cool-retro-term

    # Text
    helix

    # Media Players
    mpv
    vlc

    # Image Viewer
    imv

    # PDF
    zathura

    # GUI
    code-cursor
    signal-desktop

    # Trezor
    trezord
    trezor-suite

    # Ledger
    ledger-live-desktop
  ];
}
