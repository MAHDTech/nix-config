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
    code-cursor
  ];
in
{
  home.packages =
    with pkgs;
    [
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
      #code-cursor
      signal-desktop
      google-chrome
      remmina

      # Trezor
      trezor-suite
      trezor-agent

      # Ledger
      ledger-live-desktop

      # Development
      go
      golangci-lint
      gotools
    ]
    ++ unstablePkgs;
}
