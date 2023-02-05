{ config, lib, pkgs, ... }:

##################################################
# Name: smartcards.nix
# Description: Nix home-manager config for smart cards.
##################################################

{

  home.packages = with pkgs; [

    # Common
    ccid
    hidapi
    libfido2
    libu2f-host
    libusb-compat-0_1
    #libusb-compat
    libusb1
    opensc
    pam_u2f
    pcsclite
    pinentry

    # Ledger
    ledger-udev-rules

    # Trezor
    trezor-udev-rules
    trezor_agent

    # YubiKey
    yubico-pam
    yubico-piv-tool
    yubihsm-connector
    yubikey-manager
    yubikey-manager-qt
    yubikey-personalization
    yubikey-personalization-gui
    yubikey-touch-detector

  ];

}

