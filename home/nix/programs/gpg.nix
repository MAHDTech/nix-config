{
  config,
  pkgs,
  lib,
  ...
}:
##################################################
# NOTES:
#
#   For YubiKey first-time setup;
#
#     - Set the PINs for user and admin.
#
#       gpg --card-edit
#       admin
#       passwd
#
#     - Enable touch settings
#
#       ykman openpgp keys set-touch aut on
#       ykman openpgp keys set-touch sig on
#       ykman openpgp keys set-touch enc on
#
#     - Check the status
#
#       gpg --card-status
#
#   For importing from YubiKey;
#
#     - Import the keys
#
#       gpg --card-edit
#       fetch
#
#   Or;
#
#     gpg --import key.asc
#
#   For WSL v2 nonsense, see;
#     https://learn.microsoft.com/en-us/windows/wsl/connect-usb
#
#   To Test GPG;
#
#     echo "This is a test message for YubiKey signing." | gpg --sign --armor --output test.sig
#     gpg --verify test.sig
#
#   To Test GPG with 1Password;
#
#     gpg --list-keys
#     gpg --list-secret-keys
#
#   NOTE: SOPS doesn't play nice with KBX, so run this;
#
#     gpg --export > ~/.gnupg/pubring.gpg
#     gpg --export-secret-keys > ~/.gnupg/secring.gpg
#
##################################################
let
  # Holds a concatenated list of all GPG public keys in the secrets/keys directory.
  gpg-public-keys =
    let
      keysDir = ../../../secrets/keys;
      findAscFiles =
        dir:
        let
          entries = builtins.readDir dir;
          files = lib.mapAttrsToList (
            name: type:
            let
              path = dir + "/${name}";
            in
            if type == "regular" && lib.hasSuffix ".asc" name then
              [ path ]
            else if type == "directory" then
              findAscFiles path
            else
              [ ]
          ) entries;
        in
        lib.flatten files;
      # Get all .asc files and read their contents
      ascFiles = findAscFiles keysDir;
      readFiles = map (path: builtins.readFile path) ascFiles;
    in
    lib.concatStringsSep "\n\n" readFiles;

in
{
  home.packages = with pkgs; [
  ];

  # GPG (Client)
  programs = {
    gpg = {
      enable = true;

      package = pkgs.gnupg;

      homedir = "${config.home.homeDirectory}/.gnupg";

      # If required, allow users to make changes via the gpg cli.
      mutableKeys = true;
      mutableTrust = true;

      # Read all public keys from this file.
      publicKeys = [ { source = "${config.xdg.configFile.pubkeys.source}"; } ];

      # PCSCD
      # Smart Card Daemon settings.
      # https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-Options.html
      scdaemonSettings = {
        # Disable the Internal CCID driver and rely on PC/SCD instead.
        disable-ccid = true;

        # Reader Port (not needed when using PC/SC Daemon)
        # Set a name for the reader port (YubiKey 4 or NEO)
        #reader-port = "Yubico Yubikey" ;
        # Set a name for the reader port (YubiKey 5)
        #reader-port = "Yubico Yubi";
      };

      # Define GPG user settings.
      # gpgconf --list-options gpg-agent
      settings = {
        # Set the default key
        default-key = "MAHDTech (Salt Labs) <mahdtech@saltlabs.tech>";

        # Disable inclusion of the version string in ASCII armored output
        no-emit-version = true;

        # Disable comment string in clear text signatures and ASCII armored messages
        no-comments = true;

        # Display long key IDs
        keyid-format = "0xlong";

        # Display the calculated validity of user IDs during key listings
        list-options = "show-uid-validity";
        verify-options = "show-uid-validity";

        # Try to use the GnuPG-Agent. With this option, GnuPG first tries to connect to
        # the agent before it asks for a passphrase.
        use-agent = true;

        # Allow a fake pinentry for hardware GPG keys.
        pinentry-mode = "loopback";

        throw-keyids = true;

        no-symkey-cache = true;

        require-cross-certification = true;

        fixed-list-mode = true;

        # This is the server that --recv-keys, --send-keys, and --search-keys will
        # communicate with to receive keys from, send keys to, and search for keys on
        keyserver = "hkps://keys.openpgp.org/";

        keyserver-options = [
          # Set the proxy to use for HTTP and HKP keyservers - default to the standard
          # local Tor socks proxy
          # It is encouraged to use Tor for improved anonymity. Preferably use either a
          # dedicated SOCKSPort for GnuPG and/or enable IsolateDestPort and
          # IsolateDestAddr
          #keyserver-options http-proxy=socks5-hostname://127.0.0.1:9050

          # When using --refresh-keys, if the key in question has a preferred keyserver
          # URL, then disable use of that preferred keyserver to refresh the key from
          "no-honor-keyserver-url"

          # When searching for a key with --search-keys, include keys that are marked on the keyserver as revoked
          "include-revoked"
        ];

        # Disable TTY
        no-tty = false;

        # list of personal digest preferences. When multiple digests are supported by
        # all recipients, choose the strongest one
        personal-cipher-preferences = [
          "AES256"
          "AES192"
          "AES"
        ];

        # list of personal digest preferences. When multiple ciphers are supported by
        # all recipients, choose the strongest one
        personal-digest-preferences = [
          "SHA512"
          "SHA384"
          "SHA256"
        ];

        # Compression preferences
        personal-compress-preferences = [
          "ZLIB"
          "BZIP2"
          "ZIP"
          "Uncompressed"
        ];

        # message digest algorithm used when signing a key
        cert-digest-algo = "SHA512";
        s2k-digest-algo = "SHA512";
        s2k-cipher-algo = "AES256";

        # This preference list is used for new keys and becomes the default for
        # "setpref" in the edit menu
        default-preference-list = [
          "SHA512"
          "SHA384"
          "SHA256"
          "AES256"
          "AES192"
          "AES"
          "ZLIB"
          "BZIP2"
          "ZIP"
          "Uncompressed"
        ];
      };
    };
  };

  # GPG (Agent)
  services = {
    gpg-agent = {
      # NOTE:
      #   - PCSCD conflicts with gpg-agent
      #   - gnome-keyring is no longer a wrapper for gpg-agent
      #   - 1Password is currently the preferred gpg-agent for git
      #   - Or use yubikey gpg for everything else.
      enable = false;

      enableBashIntegration = true;
      enableFishIntegration = false;
      enableZshIntegration = false;

      enableExtraSocket = true;
      enableSshSupport = false;
      enableScDaemon = true;

      defaultCacheTtl = 60480000;
      defaultCacheTtlSsh = 60480000;
      maxCacheTtl = 60480000;
      maxCacheTtlSsh = 60480000;

      grabKeyboardAndMouse = true;

      #pinentryFlavor = "gnome3";

      # gpg --list-keys --with-keygrip
      sshKeys = [ ];

      extraConfig = ''

        allow-emacs-pinentry
        allow-loopback-pinentry

      '';
    };
  };

  xdg.configFile = {
    "pubkeys" = {
      target = "nixpkgs/files/pubkeys.txt";
      text = gpg-public-keys;
    };
  };
}
