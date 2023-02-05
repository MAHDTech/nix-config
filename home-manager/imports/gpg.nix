{ config, lib, pkgs, ... }:

##################################################
# Name: gpg.nix
# Description: Nix home-manager config for GNUPG
##################################################

{

  home.packages = with pkgs; [

    gnupg

  ];

  programs.gpg = {

    enable = true ;

    package = pkgs.gnupg ;

    homedir = "${config.home.homeDirectory}/.gnupg" ;

    # If required, allow users to make changes via the gpg cli.
    mutableKeys = true ;
    mutableTrust = true ;

    # Read all public keys from this file.
    publicKeys = [
      {
        source = "${config.xdg.configFile.pubkeys.source}" ;
      }
    ];

    # Smart Card Daemon settings.
    # https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-Options.html
    scdaemonSettings = {

      # Ensure CCID is not disabled.
      disable-ccid = false ;

      # Set a name for the reader port (YubiKey 4 or NEO)
      #reader-port "Yubico Yubikey" ;

      # Set a name for the reader port (YubiKey 5)
      #reader-port "Yubico Yubi" ;

    };

    # Define GPG user settings.
    # gpgconf --list-options gpg-agent
    settings = {

      # Set the default key
      #default-key = "MAHDTech (Salt Labs) <mahdtech@saltlabs.tech>" ;

      # Disable inclusion of the version string in ASCII armored output
      no-emit-version = true ;

      # Disable comment string in clear text signatures and ASCII armored messages
      no-comments = true ;

      # Display long key IDs
      keyid-format = "0xlong" ;

      # Display the calculated validity of user IDs during key listings
      list-options = "show-uid-validity" ;
      verify-options = "show-uid-validity" ;

      # Try to use the GnuPG-Agent. With this option, GnuPG first tries to connect to
      # the agent before it asks for a passphrase.
      use-agent = true ;

      throw-keyids = true ;

      no-symkey-cache = true ;

      require-cross-certification = true ;

      fixed-list-mode = true ;

      # This is the server that --recv-keys, --send-keys, and --search-keys will
      # communicate with to receive keys from, send keys to, and search for keys on
      keyserver = "hkps://keys.openpgp.org/" ;

      keyserver-options = [

        # Set the proxy to use for HTTP and HKP keyservers - default to the standard
        # local Tor socks proxy
        # It is encouraged to use Tor for improved anonymity. Preferrably use either a
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
      no-tty = false ;

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
      cert-digest-algo = "SHA512" ;
      s2k-digest-algo = "SHA512" ;
      s2k-cipher-algo = "AES256" ;

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

  services.gpg-agent = {

    enable = true;

    enableBashIntegration = true ;
    enableFishIntegration = false ;
    enableZshIntegration = false ;

    enableExtraSocket = false ;
    enableSshSupport = false ;
    enableScDaemon = true ;

    defaultCacheTtl = 60480000;
    defaultCacheTtlSsh = 60480000;
    maxCacheTtl = 60480000;
    maxCacheTtlSsh = 60480000;

    grabKeyboardAndMouse = true ;

    pinentryFlavor = "gnome3";

    # gpg --list-keys --with-keygrip
    sshKeys = [

    ];

    extraConfig = ''

      allow-emacs-pinentry
      allow-loopback-pinentry

    '';

  };

  xdg.configFile = {

    "pubkeys" = {

      target = "nixpkgs/files/pubkeys.txt" ;

      text = ''
      '';

    };

  };

}

