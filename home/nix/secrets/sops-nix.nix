{
  config,
  pkgs,
  lib,
  ...
}:
let
  keystoreFile = ../../../secrets/keystore.yaml;
in
{
  # NOTE: Any services that rely on secrets stored in SOPS need to be setup with:
  #       systemd.user.services.XXX.Unit.After = [ "sops-nix.service" ];

  home.activation = {
    setupSopsAgeKey = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      # 1. Ensure ~/.ssh directory exists with correct permissions
      run mkdir -p "${config.home.homeDirectory}/.ssh"
      run chmod 700 "${config.home.homeDirectory}/.ssh"

      # 2. Generate SSH ed25519 key if missing
      if [ ! -f "${config.home.homeDirectory}/.ssh/id_ed25519" ]; then
        echo "Generating SSH ed25519 key..."
        run ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f "${config.home.homeDirectory}/.ssh/id_ed25519"
      fi

      # 3. Generate SSH RSA key if missing
      if [ ! -f "${config.home.homeDirectory}/.ssh/id_rsa" ]; then
        echo "Generating SSH RSA key..."
        run ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -N "" -f "${config.home.homeDirectory}/.ssh/id_rsa"
      fi

      # 4. Ensure target directory exists for age keys
      run mkdir -p "${config.home.homeDirectory}/.config/sops/age"

      # 5. Generate age keys.txt if missing (deriving from ~/.ssh/id_ed25519)
      if [ ! -f "${config.home.homeDirectory}/.config/sops/age/keys.txt" ]; then
        if [ -f "${config.home.homeDirectory}/.ssh/id_ed25519" ]; then
          echo "Generating SOPS age key from ~/.ssh/id_ed25519..."
          run ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "${config.home.homeDirectory}/.ssh/id_ed25519" -o "${config.home.homeDirectory}/.config/sops/age/keys.txt"
          run chmod 600 "${config.home.homeDirectory}/.config/sops/age/keys.txt"
        fi
      fi
    '';
  };

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
