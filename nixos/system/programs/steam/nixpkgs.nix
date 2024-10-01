{
  config,
  pkgs,
  ...
}: {
  imports = [];

  hardware.opengl.driSupport32Bit = true;
  hardware.steam-hardware.enable = true;

  programs.java.enable = true;

  nixpkgs.config.packageOverrides = pkgs: {
    # Steam
    steam = pkgs.steam.override {
      withJava = true;
      extraPkgs = pkgs:
        with pkgs; [
          curlFull
          expat
          glxinfo
          gnutls
          glxinfo
          gtk3
          gtk3-x11
          ibxkbcommon
          intel-gpu-tools
          intel-media-driver
          libgdiplus
          libstdcxx5
          libva-utils
          libvdpau-va-gl
          mesa
          mono
          vaapiIntel
          vaapiVdpau
          vdpauinfo
          wayland
          zlib
        ];
    };

    # Steam Run
    steam-run = pkgs.steamrun.override {
      extraLibraries = pkgs:
        with pkgs; [
          ibxkbcommon
          libgdiplus
          mesa
          wayland
          glxinfo
        ];
    };
  };

  environment.systemPackages = with pkgs; [
    #steam
    #steam-run
    #steam-run-native
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
  };
}
