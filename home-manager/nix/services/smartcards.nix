{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
# FYI: YubiKey reset instructions.
# https://support.yubico.com/hc/en-us/articles/360013761339-Resetting-the-OpenPGP-Application-on-the-YubiKey
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs;
    [
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

      # Trezor
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
    ]
    ++ unstablePkgs;
}
