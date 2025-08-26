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

  # Configure OpenSC as a PKCS#11 module in p11-kit
  # This is needed to use the EID cards in the web browser.
  # Run pkcs15-tool --list-certificates to see the certificates on the card.
  environment = {
    etc."pkcs11/modules/opensc-pkcs11".text = ''
      module: ${pkgs.opensc}/lib/opensc-pkcs11.so
    '';
  };
}
