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

  # Add UDEV rules for Smart Cards
  # REMEMBER: Run these commands to reload the udev rules:
  # sudo udevadm control --reload-rules
  # sudo udevadm trigger
  # sudo udevadm settle
  services = {
    udev = {
      extraRules = ''
        # Identiv SCR3500 Smart Card Reader
        SUBSYSTEM=="usb", ATTR{idVendor}=="04e6", ATTR{idProduct}=="5814", MODE="0666", TAG+="uaccess"

        # Generic smart card reader rules
        SUBSYSTEM=="usb", ATTR{idVendor}=="04e6", MODE="0666", TAG+="uaccess"
        SUBSYSTEM=="usb", ATTR{bDeviceClass}=="0b", MODE="0666", TAG+="uaccess"

        # CCID compliant devices
        SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="0b", MODE="0666", TAG+="uaccess"

        # Reload pcscd when smart card readers are added/removed
        ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04e6", RUN+="${pkgs.systemd}/bin/systemctl try-reload-or-restart pcscd.service"
        ACTION=="remove", SUBSYSTEM=="usb", ATTR{idVendor}=="04e6", RUN+="${pkgs.systemd}/bin/systemctl try-reload-or-restart pcscd.service"

        # EOF - Smart Cards
      '';
    };
  };
}
