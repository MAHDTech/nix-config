{ config, lib, nixpkgs, pkgs, ... }:

{

  imports = [

    <sops-nix/modules/sops>

  ];

  environment.systemPackages = with pkgs; [

  ];

  sops = {

    # This will add secrets.yml to the nix store
    # You can avoid this by adding a string to the full path instead, i.e.
    # sops.defaultSopsFile = "/root/.sops/secrets/example.yaml";
    defaultSopsFile = ../../../secrets.yaml;

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

    # This is the actual specification of the secrets.
    secrets = {

      "wakatime/api-key" = {};

    };

  };

}
