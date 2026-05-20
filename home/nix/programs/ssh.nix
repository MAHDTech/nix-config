{
  config,
  lib,
  ...
}:
##################################################
# NOTES:
#
#   * This configuration now uses 1Password SSH Agent.
#
#   * This configuration previously uses the OpenSSH Agent
#     instead of the GPG Agent for SSH.
#
#   * The SSH keys from the smart cards are loaded
#     into the agent during loading of .bashrc
#
#   * If you have a YubiKey 5, use the newer method
#     described below that uses resident sk keys.
#     https://www.yubico.com/blog/github-now-supports-ssh-security-keys/
#
#     For YubiKey with resident keys
#
#       - First time setup.
#           mkdir -p ~/.ssh/
#           ssh-keygen \
#             -C MAHDTech@saltlabs.tech \
#             -t ed25519-sk \
#             -O resident \
#             -O verify-required \
#             -f ~/.ssh/id_ed25519_sk
#
#       - On new systems;
#           ssh-keygen -K
#
##################################################
{
  # WORKAROUND: Workaround for the dreaded "bad owner or permissions on ~/.ssh/config"
  # Reference: https://github.com/nix-community/home-manager/issues/322

  home.file = {
    # Force home-manager to own the file.
    ".ssh/config".force = true;
  };

  home.activation = {
    # https://github.com/nix-community/home-manager/issues/322
    fixSshPermissions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -d -m 0700 "$HOME/.ssh"
      if [ -L "$HOME/.ssh/config" ];
      then
        src="$(readlink -f "$HOME/.ssh/config")"
        run rm -f "$HOME/.ssh/config"
        run install -m 0600 "$src" "$HOME/.ssh/config"
      fi
    '';
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Include any extra files with SSH config.
    includes = [ ];

    # Apply overrides to specific hosts.
    settings = {
      #########################
      # Global
      #########################

      "*" = {
        Compression = "yes";

        ControlMaster = "auto";
        ControlPath = "~/.ssh/control-master/%r@%h:%p";
        ControlPersist = "3600";

        HashKnownHosts = "no";

        ForwardAgent = "yes";

        ServerAliveCountMax = 3;
        ServerAliveInterval = 60;

        RemoteForward = "/run/user/1000/gnupg/S.gpg-agent.extra /home/mahdtech/.gnupg/S.gpg-agent.extra";
        SecurityKeyProvider = "internal";

        # Use the 1Password SSH Agent.
        IdentityAgent = "${config.home.homeDirectory}/.1password/agent.sock";

        # openssh_gssapi pkg includes the needed support.
        # IgnoreUnknown = "gssapikexalgorithms,gssapiauthentication,gssapidelegatecredentials";
      };

      #########################
      # Internet
      #########################

      "github.com" = {
        HostName = "github.com";
        User = "git";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "gitlab.com" = {
        HostName = "gitlab.com";
        User = "git";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      #########################
      # Salt Labs
      #########################

      "bootycall" = {
        HostName = "bootycall.saltlabs.cloud";
        User = "root";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      ##################################################
      # TARS Cloud
      ##################################################

      #########################
      # Lander (Load Balancer)
      #########################

      "lander-01" = {
        HostName = "lander-01.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      #########################
      # Horizon (CASE Workers)
      #########################

      "horizon-01" = {
        HostName = "horizon-01.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "horizon-02" = {
        HostName = "horizon-02.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "horizon-03" = {
        HostName = "horizon-03.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "horizon-04" = {
        HostName = "horizon-04.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "horizon-05" = {
        HostName = "horizon-05.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "horizon-06" = {
        HostName = "horizon-06.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      #########################
      # Tesseract (BUFFER)
      #########################

      "tesseract-01" = {
        HostName = "tesseract-01.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "tesseract-02" = {
        HostName = "tesseract-02.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "tesseract-03" = {
        HostName = "tesseract-03.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "tesseract-04" = {
        HostName = "tesseract-04.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      #########################
      # Lazarus / KIPP (Drones)
      #########################

      "lazarus-01" = {
        HostName = "lazarus-01.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-02" = {
        HostName = "lazarus-02.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-03" = {
        HostName = "lazarus-03.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-04" = {
        HostName = "lazarus-04.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-05" = {
        HostName = "lazarus-05.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-06" = {
        HostName = "lazarus-06.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-07" = {
        HostName = "lazarus-07.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-08" = {
        HostName = "lazarus-08.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-09" = {
        HostName = "lazarus-09.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-10" = {
        HostName = "lazarus-10.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-11" = {
        HostName = "lazarus-11.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      "lazarus-12" = {
        HostName = "lazarus-12.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      #########################
      # Romilly (Storage & Observability)
      #########################

      "romilly-01" = {
        HostName = "romilly-01.tars-cloud.ai";
        User = "cooper";
        PasswordAuthentication = "no";
        PubkeyAuthentication = "yes";
      };

      #########################
      # UniFi
      #########################

      "unifi" = {
        HostName = "10.10.1.254";
        User = "root"; # Use root and not ubnt.
        PasswordAuthentication = "yes";
        PreferredAuthentications = "keyboard-interactive";
        PubkeyAuthentication = "no";
      };

      #########################
      # Bingamon
      #########################

      "bingamon-jumpbox" = {
        HostName = "192.168.85.76";
        User = "linadmin";
        PasswordAuthentication = "yes";
        PubkeyAuthentication = "yes";
      };
    };
  };
}
