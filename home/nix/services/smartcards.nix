{ pkgs, ... }:
{

  home.packages = with pkgs; [
    # Common
    acsccid
    ccid
    hidapi
    libfido2
    libu2f-host
    libusb-compat-0_1
    libusb1
    opensc
    nssTools
    pam_u2f
    pcsc-cyberjack
    pcsc-safenet
    pcsc-scm-scl011
    pcsc-tools
    pcsclite
    pinentry
    scmccid

    # YubiKey
    # NOTE: For YubiKey reset instructions see: https://support.yubico.com/hc/en-us/articles/360013761339-Resetting-the-OpenPGP-Application-on-the-YubiKey
    yubico-pam
    yubico-piv-tool
    yubikey-manager
    yubioath-flutter
    yubikey-personalization
    yubikey-touch-detector
    swig
  ];
}
