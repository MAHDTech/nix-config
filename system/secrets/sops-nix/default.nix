{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  sops = {
    # This will add secrets.yml to the nix store
    # You can avoid this by adding a string to the full path instead, i.e.
    # defaultSopsFile = "/root/.sops/secrets/example.yaml";
    defaultSopsFile = ../../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      # This will automatically import SSH keys as age keys
      # NOTE: Only ED25519 keys are supported at present.
      sshKeyPaths = [
        # System
        "/etc/ssh/ssh_host_ed25519_key"

        # User
        "/home/mahdtech/.ssh/keys/id_ed25519"
      ];

      # This is using an age key that is expected to already be in the filesystem
      keyFile = "/home/mahdtech/config/sops/age/keys.txt";

      # This will generate a new key if the key specified above does not exist
      generateKey = false;
    };

    gnupg = {
      #home = "/var/lib/sops";

      # This must be disabled when home is set.
      # NOTE: Only RSA keys are supported at present.
      sshKeyPaths = [
        # System
        "/etc/ssh/ssh_host_rsa_key"
        #"/etc/ssh/ssh_host_ed25519_key"

        # User
        #"/home/mahdtech/.ssh/keys/id_ed25519"
      ];
    };

    # This is the actual specification of the secrets that
    # will be available to the system at /run/secrets.d/
    /*
    secrets = {

    github_token = {
      sopsFile = ../../../secrets/secrets.yaml;
      format = "yaml";
      mode = "0400";
      owner = config.users.users.mahdtech.name;
      group = config.users.users.mahdtech.group;
      neededForUsers = false;
    };

    wakatime_token = {
      sopsFile = ../../../secrets/secrets.yaml;
      format = "yaml";
      mode = "0400";
      owner = config.users.users.mahdtech.name;
      group = config.users.users.mahdtech.group;
      neededForUsers = false;
    };

    };
    */
  };
}
