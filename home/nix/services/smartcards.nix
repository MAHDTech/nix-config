{pkgs, ...}: {
  home.packages = with pkgs; [
    # Common
    ccid
    hidapi
    libfido2
    libu2f-host
    libusb-compat-0_1
    libusb1
    opensc
    pam_u2f
    pcsclite
    pinentry

    # YubiKey
    # NOTE: For YubiKey reset instructions see: https://support.yubico.com/hc/en-us/articles/360013761339-Resetting-the-OpenPGP-Application-on-the-YubiKey
    yubico-pam
    yubico-piv-tool
    yubikey-manager
    yubikey-manager-qt
    yubikey-personalization
    yubikey-personalization-gui
    yubikey-touch-detector
    swig
  ];
}
