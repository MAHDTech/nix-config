{
  inputs,
  pkgs,
  ...
}:
let
  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  unstablePkgs = with pkgsUnstable; [
    claude-agent-acp
    claude-code
    claude-monitor
  ];

  systemArchPackages =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      with pkgs;
      [
        # x86_64 only packages
        #google-chrome
        ledger-live-desktop
        onlyoffice-desktopeditors

        # Screen recorder
        gpu-screen-recorder
        gpu-screen-recorder-gtk
      ]
    else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
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
      nil
      nixfmt

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
      fastfetch
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

      # Diagrams
      #drawio

      # Video Editor
      shotcut

      # PDF
      zathura

      # GUI
      #signal-desktop
      remmina
      brave

      # Trezor
      trezor-suite
      #trezor-agent

      # Development
      go
      golangci-lint
      gotools
      prek

      # 3D Printing
      orca-slicer # OSS version of Bambu Studio
    ]
    ++ unstablePkgs
    ++ systemArchPackages;
}
