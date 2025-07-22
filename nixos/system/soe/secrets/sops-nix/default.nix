{
  config,
  pkgs,
  ...
}:
let
  keystoreFile = ../../../../.. + "/secrets/keystore.yaml";
in
{
  imports = [ ];

  environment.systemPackages = with pkgs; [ ];

  sops = {
    # This option expects a value of type `path`.
    defaultSopsFile = keystoreFile;
    defaultSopsFormat = "yaml";

    # NOTE: Only ED25519 keys are supported with age.
    age = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
      ];

      # This is where the key file lives on the local system.
      keyFile = "/var/lib/sops-nix/key.txt";

      # This will generate a new key if the key specified above does not exist
      generateKey = true;
    };

    # NOTE: Only RSA keys are supported with gpg.
    gnupg = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_rsa_key"
      ];
    };

    #########################################################
    # Secrets
    #
    # Defined secrets are available to the system at /run/secrets/
    #
    #########################################################

    secrets = {

      # Cloudflare Email for ACME.
      "incus/acme/cloudflare/email" = {
        sopsFile = keystoreFile;
        format = "yaml";
        mode = "0400";
        owner = "root";
        group = "root";
        neededForUsers = false;
        restartUnits = [
          "incus-preseed.service"
        ];
      };

      # Cloudflare API Key for ACME.
      "incus/acme/cloudflare/apiKey" = {
        sopsFile = keystoreFile;
        format = "yaml";
        mode = "0400";
        owner = "root";
        group = "root";
        neededForUsers = false;
        restartUnits = [
          "incus-preseed.service"
        ];
      };
    };

    #########################################################
    # Templates
    #
    # Templates are used to populate placeholder values in files at runtime.
    #
    #########################################################

    templates = {
      "incus-acme.env" = {
        owner = "root";
        content = ''
          CLOUDFLARE_EMAIL="${config.sops.placeholder."incus/acme/cloudflare/email"}"
          CLOUDFLARE_API_KEY="${config.sops.placeholder."incus/acme/cloudflare/apiKey"}"
        '';
      };
    };
  };
}
