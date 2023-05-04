{
  inputs,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePkgs = with pkgsUnstable; [];
in {
  home.packages = with pkgs;
    [gcr gnome.gnome-keyring gnome.seahorse libsecret] ++ unstablePkgs;

  services = {
    gnome-keyring = {
      enable = false;

      # GPG is managed seperately.
      components = ["pkcs11" "secrets" "ssh"];
    };
  };
}
