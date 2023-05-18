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
      binutils
      bottom
      bzip2
      coreutils
      curlFull
      dos2unix
      edid-decode
      exa
      fd
      figlet
      file
      fortune
      hello
      htop
      inetutils
      jq
      libcap
      locale
      lolcat
      mkpasswd
      ncdu
      neofetch
      nushell
      openssh
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
      sops
      tokei
      tree
      unzip
      usbutils
      wally-cli
      wget
      xdotool
      xsv
      xxd
      youtube-dl
      zip
      zsa-udev-rules
    ]
    ++ unstablePkgs;
}
