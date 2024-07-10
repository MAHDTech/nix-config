{
  inputs,
  config,
  pkgs,
  ...
}:
##################################################
# NOTES:
#
#   For YubiKey first-time setup;
#     gpg --card-edit
#     admin
#     passwd
#
#     ykman openpgp keys set-touch aut on
#     ykman openpgp keys set-touch sig on
#     ykman openpgp keys set-touch enc on
##################################################
let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  #home.packages = with pkgs; [] ++ unstablePkgs;

  programs.gpg = {
    enable = false;

    package = pkgs.gnupg;

    homedir = "${config.home.homeDirectory}/.gnupg";

    # If required, allow users to make changes via the gpg cli.
    mutableKeys = true;
    mutableTrust = true;

    # Read all public keys from this file.
    publicKeys = [{source = "${config.xdg.configFile.pubkeys.source}";}];

    # Smart Card Daemon settings.
    # https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-Options.html
    scdaemonSettings = {
      # Ensure CCID is not disabled.
      disable-ccid = false;

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
      personal-cipher-preferences = ["AES256" "AES192" "AES"];

      # list of personal digest preferences. When multiple ciphers are supported by
      # all recipients, choose the strongest one
      personal-digest-preferences = ["SHA512" "SHA384" "SHA256"];

      # Compression preferences
      personal-compress-preferences = ["ZLIB" "BZIP2" "ZIP" "Uncompressed"];

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

  services.gpg-agent = {
    # NOTE:
    #   - PCSCD conflicts with gpg-agent
    #   - gnome-keyring is no longer a wrapper for gpg-agent
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
    sshKeys = [];

    extraConfig = ''

      allow-emacs-pinentry
      allow-loopback-pinentry

    '';
  };

  xdg.configFile = {
    "pubkeys" = {
      target = "nixpkgs/files/pubkeys.txt";

      text = ''
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Comment: MAHDTech@saltlabs.tech

        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
        =nDnz
        -----END PGP PUBLIC KEY BLOCK-----

        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Comment: NUC

        xsFNBAAAAAABEAC6+IygcsjiK0+fIzog6BnKkiSwyoI2I8zzntJFuG5e6l7XDOQQ
        7h92Cm6JSEwdRt6D+gjoYERyoCvCxi+kK+Zgm051M3IoeH8zR0xkzi68/D6j47B7
        iBvhpjQiDqnjAPRo2UkrjWqE1XY8qCj9+DXrBd+nhyEOs0edqfbAPRSQVhaXY1bT
        XsSXK7UvOOIlVUJL3cqHPtwEvlN+q7GL+rJ2UXaB0yLw+Vo+cFaEfXbRgszPtzjB
        bXcSFSQNhCFg+E34ftHDSxQebG5I0thyJzCGpA5qNJ6sIHKL3/qdb3i2MbWQKWcS
        qnbBRWpCgYZUDVMzUpOXcBvbPFuj1SpTiKbfBmhtgoaw7nmRskq40B6bxvHRyjVq
        gKrxwdOtMJnwo4ieFgCMwLu8FVZtd7UnWMdp77xFbd2PRj60L2iIsfD4tx708z17
        WXWqK/P3qjJPGiL99iTs/mg0sw5yp75+TdW1uutVAy2xesoPvss4Pyt9RAL9/cTc
        ipt6y10iFR9GQ/WQ9kWHbVmEnMzkRLqetVR9wkn1m6lV0/QV8+E2R/40uaVRDC8q
        SHjXH7bwuOuH1LzSTZerkB3w0wmj1kIuAzNnQitVrbkMuLkzui3XmMHK6imkJ4t4
        Qb6HogljJufM49mH8DQ4pkV9Q/fzJUSyvFuTgH0pWGTDUOJRIyxuMKgxmQARAQAB
        zSlyb290IChJbXBvcnRlZCBmcm9tIFNTSCkgPHJvb3RAbG9jYWxob3N0PsLBYgQT
        AQgAFgUCAAAAAAkQ7vUpJxNKbYQCGw8CGQEAADchEAAWUpANSEnsImhnVN4vqAPU
        BSAKMsYMvgAex3xWvSF+Y++cz96JY+7sjYp7XY26fz35lLgEgTOl2CdmFFXEDxLw
        s+ODkmls9E0TBkH2ydpfDgO1mONsuPou267XmEtFVC5sg2fNGz3fAIMNW/vidk2H
        0grPeCukyjpHnh6na+kM4BXZNh8PD4FYzwZz/q34dZR7YwsV5izUtGcHxv/ssQO2
        bh0VZwuTrlGk7ZGTwAkwgvggduliDPO43WtXfldlzqZTBXU8qAy6XzjJxQyZRdJG
        BD3TIwTAh3iILZHEpoQ0Bar7cZs9RY5/Z1SZ05pyaHDbmkCleB6RYuTVYcOmK2VF
        VJc1RIvmduU1tmZ40cn0HlyfmjpcGbfhjqt/SckoAlyzDaKIMz/ydlCutpTaMVYR
        21h2g90kIzf9GktOxpv2OHnCGdrVavtiq8xoLROKqnT5g66uRmFQu4o1KH5fLZDA
        OtOEJCaIiKCFYEVD8chK/impXGIXroBYTDffY9lBbUb7QdX4b2uVc4OQSxe1atS7
        HVv2OJ+cdxzPd+SDbRak/elfSZCWqa2UdjWC2EC91/a5d3oDCJniCHsb7LnKrII6
        W13hOz6b3au5LrTBt+M+vfGTSff3USuf/mH3Gx3+pFTcS1MQJKV+73nQua74PTlR
        maJ9BabgygKRdcypdNj5zg==
        =tRUm
        -----END PGP PUBLIC KEY BLOCK-----

        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Comment: Penguin

        xsDNBAAAAAABDAC/w5IQ+wBMhBcI1hNRxVOquBdatdC0HQA1anRcSHt51NPcjCgL
        tSV0IR6tsZ06eaNQuecEvPrCO/SZLN9+3URT3B83WSdN9onL8yvogkKPd5VM/92Y
        fPX6PwBcJ+inuqWEH50VGdfy9DODHItVxaBsAO+PVSgg6kVHyMGx/bshRLA6bl9J
        e8uY87sB0PRs4Zj66PbXt8s4Yv0c8ap40zQa59vza2KfyLhWsZGrDNQr9F3OfpzE
        jc5H495wI+XkIz/gPPzPfB+S+8RYo17is/zLAJKCtmNKujKTagCXPNoaBTbSxTp8
        5rIRO47UJLmnKE6VIvwTLxMHXEXNcB10+gh8RraHWLMS69q1k8mq4/2Yf8nbvUJx
        xVgB+av209hnK3gKM3V84fM4F/oZg87UpjFHm9JxSb4ApUlgTATwnP8zYmLDz5rf
        1ENAAkQ009R9tdvl0RAQO3AQGpsl/z+hipor/3DogIfo/VRC7K7dwS5k/Of7RJE8
        g/619DcijlQO2wkAEQEAAc0pcm9vdCAoSW1wb3J0ZWQgZnJvbSBTU0gpIDxyb290
        QGxvY2FsaG9zdD7CwOIEEwEIABYFAgAAAAAJEC5RuayTjzppAhsPAhkBAADRzgwA
        MHTN/l84A3WA68ytO2Or4YvjNrQTPAsodL39qyidyRJD1/Kp9W1PepoUBaHQGGB6
        G5d0R2R6eZDZO2hq2A6xfx71LVzJqueoiqi2eSzReFHvSzhFeZJKfigEp6viLAoE
        JxfmrQsfpRqWsODlYUVNCv8JJ5dIArjvq97sCAvvXBTyy4eFSV9lbLS1NNfldji3
        dQLEF5eUjeLG87C+cQzB/tL2POX0AfSgAGmWQJIL2c0/tHt7PiLq1zU7vj59fYAf
        TEDqFf6ONvqUZeoAWU1uZB0ZsCMfeQfhUKDopxjiXTh9SSeMMhYmeXpoMuLvpBCu
        pi/DER0YZo0ysu6yvQ5GZ/V2FmeN9R8owiHfoRnF+ASPxc2zCMjQnbVxnVyN9wdW
        nEcu/gVtcXFGDM4L/kEUEg+nPaPRO4kFFDpf1p7jfkh9mUCJ1MapAOqth1+KJRBl
        4nxl7DBIt9C6A5wx77JSQJwnz8r+YR1/Yi0u5W4fAv+WX/omYFGMVqlUom8+UPt0
        =Dw0a
        -----END PGP PUBLIC KEY BLOCK-----
      '';
    };
  };
}
