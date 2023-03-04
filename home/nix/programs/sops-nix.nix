{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{

  # NOTE: Any services that rely on secrets stored in SOPS need to be setup with:
  #       systemd.user.services.mbsync.Unit.After = [ "sops-nix.service" ];

  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    # NOTE: Only ED25519 keys are supported with age.
    age = {
      sshKeyPaths = [
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
