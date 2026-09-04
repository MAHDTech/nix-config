{ pkgs, ... }:
{

  # RustDesk needs a ScreenCast portal implementation to capture the session.
  # The COSMIC desktop module already provides xdg-desktop-portal-cosmic; this
  # is a defensive restatement so the service works on hosts without COSMIC.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-cosmic ];
  };

  environment.systemPackages = with pkgs; [
    rustdesk-flutter
  ];

  services.rustdesk-server = {
    enable = true;
    signal = {
      enable = true;
      relayHosts = [ "10.10.1.93" ];
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
