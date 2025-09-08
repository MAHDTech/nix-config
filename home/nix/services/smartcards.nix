{ pkgs, ... }:
let

  # Custom script to configure the browser to use the EID cards.
  configBrowserEID = pkgs.writeShellScriptBin "config-browser-eid" ''
    #!${pkgs.bash}/bin/bash

    # NOTES:
    # - To see certificates, run:
    #     pkcs15-tool --list-certificates
    # - To see slots, run:
    #     pkcs11-tool --module opensc-pkcs11.so --list-slots

    # Variables
    declare -r NSSDB="''${HOME}/.pki/nssdb"

    ${pkgs.coreutils}/bin/echo "Configuring browser to use EID cards..."
    ${pkgs.coreutils}/bin/mkdir -p ''${NSSDB} || ${pkgs.coreutils}/bin/echo "NSS database already exists"

    ${pkgs.coreutils}/bin/echo "Creating NSS database..."
    ${pkgs.nssTools}/bin/certutil -d sql:''${NSSDB} -N --empty-password

    ${pkgs.coreutils}/bin/echo "Adding p11-kit-proxy module to NSS..."
    ${pkgs.nssTools}/bin/modutil \
      -force \
      -dbdir sql:''${NSSDB} \
      -add p11-kit-proxy \
      -libfile ${pkgs.p11-kit}/lib/p11-kit-proxy.so

    ${pkgs.coreutils}/bin/echo "Done!"
  '';

  # System architecture specific packages.
  systemArchPackages =
    if pkgs.system == "x86_64-linux" then
      with pkgs;
      [
        # x86_64 only packages.
        pcsc-safenet
        pcsc-scm-scl011
        scmccid
      ]
    else if pkgs.system == "aarch64-linux" then
      [
        # aarch64 only packages.
      ]
    else
      [ ];

in
{

  home.packages =
    with pkgs;
    [
      # Common
      acsccid
      ccid
      hidapi
      libfido2
      libu2f-host
      libusb-compat-0_1
      libusb1
      opensc
      p11-kit
      nssTools
      pam_u2f
      pcsc-cyberjack
      pcsc-tools
      pcsclite
      pinentry

      # YubiKey
      # NOTE: For YubiKey reset instructions see: https://support.yubico.com/hc/en-us/articles/360013761339-Resetting-the-OpenPGP-Application-on-the-YubiKey
      yubico-pam
      yubico-piv-tool
      yubikey-manager
      yubioath-flutter
      yubikey-personalization
      yubikey-touch-detector
      swig

      # Custom
      configBrowserEID
    ]
    ++ systemArchPackages;
}
