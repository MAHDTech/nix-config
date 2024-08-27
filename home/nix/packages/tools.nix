{pkgs, ...}: {
  home.packages = with pkgs; [
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
    glxinfo
    gptfdisk
    hello
    htop
    intel-gpu-tools
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
    wget
    xdotool
    xsv
    xxd
    zip

    # Nix
    nix-du
  ];
}
