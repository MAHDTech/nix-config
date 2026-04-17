{ config, ... }:
let
  keystoreFile = ../../../secrets/keystore.yaml;
in
{
  # NOTE: Any services that rely on secrets stored in SOPS need to be setup with:
  #       systemd.user.services.XXX.Unit.After = [ "sops-nix.service" ];

  sops = {
    defaultSopsFile = keystoreFile;
    defaultSopsFormat = "yaml";

    # NOTE: Only ED25519 keys are supported with age.
    age = {
      sshKeyPaths = [
        "${config.home.homeDirectory}/.ssh/id_ed25519"
      ];

      # This is where the key file lives on the local system.
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

      # This will generate a new key if the key specified above does not exist
      generateKey = false;
    };

    # NOTE: Only RSA keys are supported with gpg.
    gnupg = {
      sshKeyPaths = [
        "${config.home.homeDirectory}/.ssh/id_rsa"
      ];
    };

    # This is the actual specification of the secrets that
    # will be available to the system at /run/secrets.d/
    secrets = {
      "daisyui/email" = { };
      "daisyui/license" = { };
    };
  };
}
