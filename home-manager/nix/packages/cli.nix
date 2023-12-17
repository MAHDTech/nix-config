{
  pkgs,
  inputs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs;
    [
      bat
      #blackbox-terminal
      #binutils
      bottom
      bzip2
      #coreutils
      curlFull
      gptfdisk
      dos2unix
      edid-decode
      eza
      fd
      figlet
      file
      flatpak
      fortune
      hello
      htop
      #inetutils
      jq
      libcap
      locale
      lolcat
      mkpasswd
      nixos-generators
      ncdu
      neofetch
      nushell
      ntfs3g
      #openssh
      pandoc
      pciutils
      powershell
      puppeteer-cli
      rclone
      read-edid
      restic
      ripgrep
      rsync
      shadow
      shellcheck
      socat
      sops
      tokei
      tree
      unzip
      usbutils
      wally-cli
      wget
      ventoy-full
      xdotool
      xsv
      xxd
      youtube-dl
      zip
      zsa-udev-rules

      # Minikube
      #libvirt
      minikube
      #qemu
      #qemu_kvm
    ]
    ++ unstablePkgs;
}
