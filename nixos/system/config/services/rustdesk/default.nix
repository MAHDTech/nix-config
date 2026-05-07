{ pkgs, ... }:
{

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  environment.systemPackages = with pkgs; [
    rustdesk-flutter
  ];

  services.rustdesk-server = {
    enable = true;
    signal = {
      enable = true;
      relayHosts = [ "10.10.1.97" ];
      extraArgs = [
      ];
    };
    relay = {
      enable = true;
      extraArgs = [ ];
    };
    openFirewall = true;
  };
}
