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

    # NOTE: Only ED25519 keys are supported with age.
    age = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/home/mahdtech/.ssh/id_ed25519"
      ];

      # This is where the key file lives on the local system.
      keyFile = "/home/mahdtech/.config/sops/age/keys.txt";

      # This will generate a new key if the key specified above does not exist
      generateKey = false;
    };

    # NOTE: Only RSA keys are supported with gpg.
    gnupg = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_rsa_key"
        "/home/mahdtech/.ssh/id_rsa"
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
