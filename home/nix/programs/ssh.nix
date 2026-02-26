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
    matchBlocks = {
      #########################
      # Global
      #########################

      "*" = {
        compression = true;

        controlMaster = "auto";
        controlPath = "~/.ssh/control-master/%r@%h:%p";
        controlPersist = "3600";

        hashKnownHosts = false;

        forwardAgent = true;

        serverAliveCountMax = 3;
        serverAliveInterval = 60;

        extraOptions = {
          RemoteForward = "/run/user/1000/gnupg/S.gpg-agent.extra /home/mahdtech/.gnupg/S.gpg-agent.extra";
          SecurityKeyProvider = "internal";

          # Use the 1Password SSH Agent.
          identityAgent = "${config.home.homeDirectory}/.1password/agent.sock";

          # openssh_gssapi pkg includes the needed support.
          # IgnoreUnknown = "gssapikexalgorithms,gssapiauthentication,gssapidelegatecredentials";
        };
      };

      #########################
      # Internet
      #########################

      "github.com" = {
        host = "github.com";
        hostname = "github.com";
        user = "git";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "gitlab.com" = {
        host = "gitlab.com";
        hostname = "gitlab.com";
        user = "git";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      #########################
      # Salt Labs
      #########################

      "bootycall" = {
        host = "bootycall";
        hostname = "bootycall.saltlabs.cloud";
        user = "root";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      ##################################################
      # TARS Cloud
      ##################################################

      #########################
      # Lander (Load Balancer)
      #########################

      "lander-01" = {
        host = "lander-01";
        hostname = "lander-01.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      #########################
      # Horizon (CASE Workers)
      #########################

      "horizon-01" = {
        host = "horizon-01";
        hostname = "horizon-01.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "horizon-02" = {
        host = "horizon-02";
        hostname = "horizon-02.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "horizon-03" = {
        host = "horizon-03";
        hostname = "horizon-03.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "horizon-04" = {
        host = "horizon-04";
        hostname = "horizon-04.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "horizon-05" = {
        host = "horizon-05";
        hostname = "horizon-05.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "horizon-06" = {
        host = "horizon-06";
        hostname = "horizon-06.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      #########################
      # Tesseract (BUFFER)
      #########################

      "tesseract-01" = {
        host = "tesseract-01";
        hostname = "tesseract-01.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "tesseract-02" = {
        host = "tesseract-02";
        hostname = "tesseract-02.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "tesseract-03" = {
        host = "tesseract-03";
        hostname = "tesseract-03.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "tesseract-04" = {
        host = "tesseract-04";
        hostname = "tesseract-04.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      #########################
      # Lazarus / KIPP (Drones)
      #########################

      "lazarus-01" = {
        host = "lazarus-01";
        hostname = "lazarus-01.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-02" = {
        host = "lazarus-02";
        hostname = "lazarus-02.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-03" = {
        host = "lazarus-03";
        hostname = "lazarus-03.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-04" = {
        host = "lazarus-04";
        hostname = "lazarus-04.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-05" = {
        host = "lazarus-05";
        hostname = "lazarus-05.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-06" = {
        host = "lazarus-06";
        hostname = "lazarus-06.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-07" = {
        host = "lazarus-07";
        hostname = "lazarus-07.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-08" = {
        host = "lazarus-08";
        hostname = "lazarus-08.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-09" = {
        host = "lazarus-09";
        hostname = "lazarus-09.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-10" = {
        host = "lazarus-10";
        hostname = "lazarus-10.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-11" = {
        host = "lazarus-11";
        hostname = "lazarus-11.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "lazarus-12" = {
        host = "lazarus-12";
        hostname = "lazarus-12.tars-cloud.ai";
        user = "cooper";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      #########################
      # UniFi
      #########################

      "unifi" = {
        host = "unifi";
        hostname = "10.10.1.254";
        user = "root"; # Use root and not ubnt.
        extraOptions = {
          PasswordAuthentication = "yes";
          PreferredAuthentications = "keyboard-interactive";
          PubkeyAuthentication = "no";
        };
      };

      #########################
      # Bingamon
      #########################

      "bingamon-jumpbox" = {
        host = "bingamon-jumpbox";
        hostname = "192.168.85.76";
        user = "linadmin";
        extraOptions = {
          PasswordAuthentication = "yes";
          PubkeyAuthentication = "yes";
        };
      };
    };
  };
}
