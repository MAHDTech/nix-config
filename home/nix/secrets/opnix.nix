{ pkgs, ... }: {
  programs.onepassword-secrets = {
    enable = true;
    secrets = {
      "sshPrivateKey" = {
        reference = "op://fleet/SSH Key/private key";
        path = ".ssh/id_ed25519";
        mode = "0600";
        group = if pkgs.stdenv.hostPlatform.isDarwin then "staff" else "users";
      };
    };
  };
}
