{pkgs, ...}: {
  home.packages = with pkgs; [gcr gnome-keyring seahorse libsecret];

  services = {
    # NOTE: There can only be one enabled (gnome-keyring vs pass-secret-service)

    # Gnome Keyring
    gnome-keyring = {
      enable = true;

      # GPG is managed separately as its deprecated in gnome-keyring.
      # https://lists.gnupg.org/pipermail/gnupg-devel/2014-August/028689.html
      # https://github.com/NixOS/nixpkgs/issues/7891
      #components = ["pkcs11" "secrets" "ssh"];

      # Use 1Password SSH Agent instead of gnome-keyring.
      components = ["pkcs11" "secrets"];
    };
  };
}
