{config, ...}:
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
  programs.ssh = {
    enable = true;

    compression = true;

    controlMaster = "auto";
    controlPath = "~/.ssh/control-master/%r@%h:%p";
    controlPersist = "3600";

    hashKnownHosts = false;

    forwardAgent = true;

    serverAliveCountMax = 3;
    serverAliveInterval = 60;

    # Include any extra files with SSH config.
    includes = [];

    # These options override any Host settings globally.
    extraOptionOverrides = {
      RemoteForward = "/run/user/1000/gnupg/S.gpg-agent.extra /home/mahdtech/.gnupg/S.gpg-agent.extra";
      SecurityKeyProvider = "internal";

      # Use the 1Password SSH Agent.
      identityAgent = "${config.home.homeDirectory}/.1password/agent.sock";
    };

    # Apply overrides to specific hosts.
    matchBlocks = {
      "github.com" = {
        host = "github.com";
        user = "git";
      };

      "ntnx-ahv-1" = {
        host = "ntnx-ahv-1";
        hostname = "ntnx-ahv-1.saltlabs.cloud";
        user = "root";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };

      "ntnx-ahv-2" = {
        host = "ntnx-ahv-2";
        hostname = "ntnx-ahv-2.saltlabs.cloud";
        user = "root";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };

      "ntnx-ahv-3" = {
        host = "ntnx-ahv-3";
        hostname = "ntnx-ahv-3.saltlabs.cloud";
        user = "root";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };

      "ntnx-ahv-4" = {
        host = "ntnx-ahv-4";
        hostname = "ntnx-ahv-4.saltlabs.cloud";
        user = "root";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };

      "ntnx-ahv-1-cvm" = {
        host = "ntnx-ahv-1-cvm";
        hostname = "ntnx-ahv-1-cvm.saltlabs.cloud";
        user = "nutanix";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };

      "ntnx-ahv-2-cvm" = {
        host = "ntnx-ahv-2-cvm";
        hostname = "ntnx-ahv-2-cvm.saltlabs.cloud";
        user = "nutanix";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };

      "ntnx-ahv-3-cvm" = {
        host = "ntnx-ahv-3-cvm";
        hostname = "ntnx-ahv-3-cvm.saltlabs.cloud";
        user = "nutanix";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };

      "ntnx-ahv-4-cvm" = {
        host = "ntnx-ahv-4-cvm";
        hostname = "ntnx-ahv-4-cvm.saltlabs.cloud";
        user = "nutanix";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };

      "jumpbox" = {
        host = "jumpbox";
        hostname = "jumpbox.saltlabs.cloud";
        user = "linadmin";
        addressFamily = "inet";
        forwardAgent = true;
        forwardX11 = false;
        forwardX11Trusted = false;
        identitiesOnly = false;
      };
    };
  };
}
