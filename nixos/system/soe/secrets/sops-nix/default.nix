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

      # Cloudflare DNS API Token for ACME.
      "incus/acme/cloudflare/dnsApiToken" = {
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

      # Cloudflare credentials for ACME.
      "incus-acme.env" = {
        owner = "root";
        content = ''
          CLOUDFLARE_DNS_API_TOKEN="${config.sops.placeholder."incus/acme/cloudflare/dnsApiToken"}"
          CLOUDFLARE_POLLING_INTERVAL=15
          CLOUDFLARE_PROPAGATION_TIMEOUT=300
          CLOUDFLARE_TTL=120
        '';
      };

    };

  };

}
