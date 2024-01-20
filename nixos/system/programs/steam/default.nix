{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Install steam using nixpkgs
    #./nixpkgs.nix
  ];

  environment.systemPackages = with pkgs; [
    proton-caller
  ];

  programs.steam = {
    enable = false;
    remotePlay.openFirewall = false;
  };
}
