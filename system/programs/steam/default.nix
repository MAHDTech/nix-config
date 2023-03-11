{
  config,
  pkgs,
  ...
}: {
  imports = [];

  nixpkgs.config.packageOverrides = pkgs: {
    steam = pkgs.steam.override {
      extraPkgs = pkgs:
        with pkgs; [
          libgdiplus
        ];
    };

    steam-run = pkgs.steamrun.override {
      extraLibraries = pkgs:
        with pkgs; [
          ibxkbcommon
          mesa
          wayland
        ];
    };
  };

  environment.systemPackages = with pkgs; [
    #steam
    #steam-run
  ];

  programs.steam = {
    enable = false;
    remotePlay.openFirewall = false;
  };
}
