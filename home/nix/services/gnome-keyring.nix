{pkgs, ...}: {
  # TODO: Solve the gnome-keyring-daemon --unlock when run as a systemd unit.
  #       For now, install gnome-keyring in the OS layer.
  #home.packages = with pkgs; [gcr gnome-keyring seahorse libsecret];
  home.packages = with pkgs; [seahorse];

  services = {
    # NOTE: There can only be one enabled (gnome-keyring vs pass-secret-service)

    # Gnome Keyring
    gnome-keyring = {
      enable = false;

      # GPG is managed separately as its deprecated in gnome-keyring
      # https://lists.gnupg.org/pipermail/gnupg-devel/2014-August/028689.html
      # https://github.com/NixOS/nixpkgs/issues/7891
      # Now SSH and GPG are both using 1Password Agent.
      components = ["pkcs11" "secrets"];
    };
  };
}
