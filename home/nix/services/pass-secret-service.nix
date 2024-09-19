{
  services = {
    # NOTE: There can only be one enabled (gnome-keyring vs pass-secret-service)
    #       For first time init run this with the 'pass' package.
    #       pass init <gpg-id> --path="$XDG_DATA_HOME/password-store"

    pass-secret-service = {
      enable = false;
    };
  };
}
