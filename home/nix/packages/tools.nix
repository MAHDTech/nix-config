{
  inputs,
  pkgs,
  ...
}:
let
  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };

  unstablePkgs = with pkgsUnstable; [
    ventoy-full
  ];

  systemArchPackages =
    if pkgs.system == "x86_64-linux" then
      with pkgs;
      [
        # x86_64 only packages
        #google-chrome
        ledger-live-desktop
        onlyoffice-desktopeditors
      ]
    else if pkgs.system == "aarch64-linux" then
      [
        # aarch64 only packages
      ]
    else
      [ ];

in
{
  home.packages =
    with pkgs;
    [
      # File management
      #insync # dead to me.
      restic
      rclone
      rsync

      # Nix
      nixos-generators
      #nix-du

      # Shell
      nushell

      # URL monitoring
      hey
      httpstat
      vegeta
      httping

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
      #unetbootin
      #syslinux # Doesn't support aarch64
      #ventoy-full

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
      s-tui
      lm_sensors
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
      tokei
      tree
      unzip
      usbutils
      which
      wget
      xdotool
      xan
      xxd
      zip

      # Sops
      sops
      age
      age-plugin-fido2-hmac
      age-plugin-ledger
      age-plugin-tpm
      age-plugin-yubikey

      # Terminal
      cool-retro-term

      # Media Players
      mpv
      vlc

      # Image Viewer
      imv

      # PDF
      zathura

      # GUI
      signal-desktop
      remmina
      brave

      # Trezor
      trezor-suite
      trezor-agent

      # Ledger

      # Development
      go
      golangci-lint
      gotools
    ]
    ++ unstablePkgs
    ++ systemArchPackages;
}
