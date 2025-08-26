{ pkgs, ... }:
{
  # Enable the PC/SC Daemon to communicate with smart cards.
  services = {
    pcscd = {
      enable = true;
      extraArgs = [ ];
      readerConfigs = [ ];
      plugins = with pkgs; [
        ccid
      ];
    };
  };

  # Enable USB Modeswitch for Smart Card Readers
  hardware = {
    usb-modeswitch = {
      enable = true;
    };
  };
}
