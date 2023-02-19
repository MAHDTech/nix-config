{ inputs, config, lib, pkgs, ... }:

{

  imports = [

  ];

  environment.systemPackages = with pkgs; [

  ];

  sops = {

    # This will add secrets.yml to the nix store
    # You can avoid this by adding a string to the full path instead, i.e.
    # defaultSopsFile = "/root/.sops/secrets/example.yaml";
    defaultSopsFile = ../../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {

      # This will automatically import SSH keys as age keys
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
      ];

      # This is using an age key that is expected to already be in the filesystem
      #keyFile = "/var/lib/sops-nix/key.txt";

      # This will generate a new key if the key specified above does not exist
      generateKey = false;

    };

    gnupg = {

      sshKeyPaths = [
        "/etc/ssh/ssh_host_rsa.key"
        "/etc/ssh/ssh_host_ed25519.key"
      ];

    };

    # This is the actual specification of the secrets.
    secrets = {

      github = {
        sopsFile = ../../../secrets/github.yaml;
        format = "yaml";
      };

      wakatime = {
        sopsFile = ../../../secrets/wakatime.yaml;
        format = "yaml";
      };

    };

  };

}
