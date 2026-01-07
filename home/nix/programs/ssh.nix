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

      #########################
      # Nutanix AHV Nodes
      #########################

      "ntnx-ce-01-ahv" = {
        host = "ntnx-ce-01-ahv";
        hostname = "ntnx-ce-01-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-02-ahv" = {
        host = "ntnx-ce-02-ahv";
        hostname = "ntnx-ce-02-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-03-ahv" = {
        host = "ntnx-ce-03-ahv";
        hostname = "ntnx-ce-03-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-04-ahv" = {
        host = "ntnx-ce-04-ahv";
        hostname = "ntnx-ce-04-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-05-ahv" = {
        host = "ntnx-ce-05-ahv";
        hostname = "ntnx-ce-05-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-06-ahv" = {
        host = "ntnx-ce-06-ahv";
        hostname = "ntnx-ce-06-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-07-ahv" = {
        host = "ntnx-ce-07-ahv";
        hostname = "ntnx-ce-07-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-08-ahv" = {
        host = "ntnx-ce-08-ahv";
        hostname = "ntnx-ce-08-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-09-ahv" = {
        host = "ntnx-ce-09-ahv";
        hostname = "ntnx-ce-09-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-10-ahv" = {
        host = "ntnx-ce-10-ahv";
        hostname = "ntnx-ce-10-ahv.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      #########################
      # Nutanix CVM VMs
      #########################

      "ntnx-ce-01-cvm" = {
        host = "ntnx-ce-01-cvm";
        hostname = "ntnx-ce-01-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-02-cvm" = {
        host = "ntnx-ce-02-cvm";
        hostname = "ntnx-ce-02-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-03-cvm" = {
        host = "ntnx-ce-03-cvm";
        hostname = "ntnx-ce-03-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-04-cvm" = {
        host = "ntnx-ce-04-cvm";
        hostname = "ntnx-ce-04-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-05-cvm" = {
        host = "ntnx-ce-05-cvm";
        hostname = "ntnx-ce-05-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-06-cvm" = {
        host = "ntnx-ce-06-cvm";
        hostname = "ntnx-ce-06-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-07-cvm" = {
        host = "ntnx-ce-07-cvm";
        hostname = "ntnx-ce-07-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-08-cvm" = {
        host = "ntnx-ce-08-cvm";
        hostname = "ntnx-ce-08-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-09-cvm" = {
        host = "ntnx-ce-09-cvm";
        hostname = "ntnx-ce-09-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      "ntnx-ce-10-cvm" = {
        host = "ntnx-ce-10-cvm";
        hostname = "ntnx-ce-10-cvm.saltlabs.cloud";
        user = "admin";
        extraOptions = {
          PasswordAuthentication = "no";
          PubkeyAuthentication = "yes";
        };
      };

      #########################
      # Prism Central
      #########################

      "ntnx-pc-01" = {
        host = "ntnx-pc-01";
        hostname = "ntnx-pc-01.saltlabs.cloud";
        user = "admin";
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
