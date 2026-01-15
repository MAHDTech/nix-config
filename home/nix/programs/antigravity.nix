{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    antigravity-fhs
  ];
}
