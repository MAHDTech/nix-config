{pkgs, ...}: {
  home.packages = with pkgs; [
    _1password-gui
    _1password
    bat
    bottom
    btop
    bzip2
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
    nixos-generators
    ntfs3g
    nushell
    pandoc
    pciutils
    rclone
    read-edid
    restic
    ripgrep
    rsync
    shadow
    shellcheck
    socat
    sops
    tailscale
    tokei
    tree
    unzip
    usbutils
    ventoy-full
    which
    wget
    xdotool
    xsv
    xxd
    zip

    # Nix
    nix-du
  ];
}
