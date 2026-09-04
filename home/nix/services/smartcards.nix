{ lib, pkgs, ... }:
let

  # Absolute path to the p11-kit PKCS#11 proxy module.
  # NOTE: NSS records this path *verbatim* inside ~/.pki/nssdb/pkcs11.txt.
  # When p11-kit is bumped by a nixpkgs update (or the old path is garbage
  # collected) the recorded path dangles, the module silently fails to load,
  # and smart cards disappear from Chromium/Brave while still working fine
  # under pkcs11-tool. The activation script below re-pins it on every switch.
  p11KitProxy = "${pkgs.p11-kit}/lib/p11-kit-proxy.so";

  nssdb = "\${HOME}/.pki/nssdb";

  # Diagnostic: walk every layer of the smart card stack and report the first
  # one that is broken. Layers 1-4 are the CLI/PCSC path, layer 5 is the NSS
  # database that Chromium/Brave actually reads.
  checkEID = pkgs.writeShellScriptBin "check-eid" ''
    set -u

    NSSDB="${nssdb}"
    fail=0

    ok()   { ${pkgs.coreutils}/bin/echo "  [ OK ] $1"; }
    bad()  { ${pkgs.coreutils}/bin/echo "  [FAIL] $1"; fail=1; }
    section() { ${pkgs.coreutils}/bin/echo ""; ${pkgs.coreutils}/bin/echo "$1"; }

    section "1. pcscd daemon"
    if ${pkgs.systemd}/bin/systemctl is-active --quiet pcscd.socket; then
      ok "pcscd.socket is active"
    else
      bad "pcscd.socket is not active -- try: sudo systemctl start pcscd.socket"
    fi

    section "2. Reader and card"
    if readers=$(${pkgs.opensc}/bin/opensc-tool --list-readers 2>&1) \
        && ${pkgs.coreutils}/bin/echo "$readers" | ${pkgs.gnugrep}/bin/grep -q "Yes"; then
      ok "card present in reader"
      ${pkgs.coreutils}/bin/echo "$readers" | ${pkgs.gnugrep}/bin/grep "Yes" | ${pkgs.gnused}/bin/sed 's/^/         /'
    else
      bad "no card detected -- is the card seated in the reader?"
    fi

    section "3. Card identity (OpenSC)"
    if name=$(${pkgs.opensc}/bin/opensc-tool --name 2>/dev/null | ${pkgs.gnugrep}/bin/grep -v "^Using reader"); then
      ok "card: $name"
    else
      bad "OpenSC cannot identify the card"
    fi

    section "4. PKCS#11 token and certificate"
    if slots=$(${pkgs.opensc}/bin/pkcs11-tool --module ${pkgs.opensc}/lib/opensc-pkcs11.so --list-slots 2>/dev/null) \
        && ${pkgs.coreutils}/bin/echo "$slots" | ${pkgs.gnugrep}/bin/grep -q "token label"; then
      ok "$(${pkgs.coreutils}/bin/echo "$slots" | ${pkgs.gnugrep}/bin/grep 'token label' | ${pkgs.gnused}/bin/sed 's/^ *//')"
    else
      bad "no PKCS#11 token -- card unreadable at the PKCS#11 layer"
    fi

    if certs=$(${pkgs.opensc}/bin/pkcs15-tool --list-certificates 2>/dev/null) \
        && ${pkgs.coreutils}/bin/echo "$certs" | ${pkgs.gnugrep}/bin/grep -q "X.509"; then
      ok "certificate readable on card"
    else
      bad "no certificate found on card"
    fi

    section "5. NSS database (what Brave/Chromium reads)"
    if [ ! -f "$NSSDB/pkcs11.txt" ]; then
      bad "no NSS database at $NSSDB -- run: home-manager switch"
    else
      recorded=$(${pkgs.gnugrep}/bin/grep -o "library=[^ ]*p11-kit-proxy.so" "$NSSDB/pkcs11.txt" | ${pkgs.gnused}/bin/sed 's/library=//')
      if [ -z "$recorded" ]; then
        bad "p11-kit-proxy not registered in NSS -- run: home-manager switch"
      elif [ ! -e "$recorded" ]; then
        bad "NSS points at a dangling store path (stale after a nixpkgs bump):"
        ${pkgs.coreutils}/bin/echo "         $recorded"
        ${pkgs.coreutils}/bin/echo "         fix with: home-manager switch"
      else
        ok "p11-kit-proxy registered and present"
      fi

      if ${pkgs.nssTools}/bin/certutil -d "sql:$NSSDB" -L -h all 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep -q "PIV\|Certificate for"; then
        ok "client certificate visible to NSS:"
        ${pkgs.nssTools}/bin/certutil -d "sql:$NSSDB" -L -h all 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep "Certificate for" | ${pkgs.gnused}/bin/sed 's/^/         /'
      else
        bad "NSS cannot see the card certificate"
      fi
    fi

    section "Result"
    if [ "$fail" -eq 0 ]; then
      ${pkgs.coreutils}/bin/echo "  Smart card is operational."
      ${pkgs.coreutils}/bin/echo ""
      ${pkgs.coreutils}/bin/echo "  If Brave still does not offer the certificate, it is holding a stale"
      ${pkgs.coreutils}/bin/echo "  NSS module list from startup. Fully quit Brave (close all windows,"
      ${pkgs.coreutils}/bin/echo "  confirm with: pgrep brave) and relaunch it."
    else
      ${pkgs.coreutils}/bin/echo "  Smart card is NOT operational -- see the [FAIL] lines above."
    fi
    exit "$fail"
  '';

  # System architecture specific packages.
  systemArchPackages =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      with pkgs;
      [
        # x86_64 only packages.
        pcsc-safenet
        pcsc-scm-scl011
        scmccid
      ]
    else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
      [
        # aarch64 only packages.
      ]
    else
      [ ];

in
{

  # Keep the NSS database that Chromium/Brave reads in sync with the current
  # p11-kit store path, on every home-manager switch.
  #
  # NOTE: `certutil -N` must only ever run against a *non-existent* database.
  # Against an existing one it does not fail cleanly -- it loops forever
  # prompting for the existing database password, which would hang activation.
  #
  # NOTE: `modutil -add` is not idempotent; re-adding an existing module fails
  # with "Failure to load dynamic library". Delete-then-add is the safe pattern.
  home.activation.configureBrowserEID = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    NSSDB="${nssdb}"

    if [ ! -f "$NSSDB/cert9.db" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$NSSDB"
      $DRY_RUN_CMD ${pkgs.nssTools}/bin/certutil -d "sql:$NSSDB" -N --empty-password < /dev/null
    fi

    # Re-pin p11-kit-proxy so a nixpkgs bump cannot leave a dangling path.
    $DRY_RUN_CMD ${pkgs.nssTools}/bin/modutil -force -dbdir "sql:$NSSDB" \
      -delete p11-kit-proxy < /dev/null > /dev/null 2>&1 || true
    $DRY_RUN_CMD ${pkgs.nssTools}/bin/modutil -force -dbdir "sql:$NSSDB" \
      -add p11-kit-proxy -libfile ${p11KitProxy} < /dev/null
  '';

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
      pinentry-gnome3

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
      checkEID
    ]
    ++ systemArchPackages;
}
