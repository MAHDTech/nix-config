{
  config,
  pkgs,
  ...
}: {
  imports = [];

  nixpkgs.config.packageOverrides = pkgs: {
    # Steam
    steam = pkgs.steam.override {
      extraPkgs = pkgs:
        with pkgs; [
          ibxkbcommon
          libgdiplus
          mesa
          wayland
          glxinfo
          libstdcxx5
          expat
          curlFull
          gnutls
          intel-media-driver
          libvdpau-va-gl
          vaapiIntel
          vaapiVdpau
          vdpauinfo
          intel-gpu-tools
          libva-utils
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
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
  };
}
