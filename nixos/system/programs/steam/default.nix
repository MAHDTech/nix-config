{
  imports = [
    # Install steam using nixpkgs
    #./nixpkgs.nix
  ];

  programs.steam = {
    enable = false;
    remotePlay.openFirewall = false;
  };
}
