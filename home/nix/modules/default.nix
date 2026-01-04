{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [ ]; # ++ unstablePkgs;
}
