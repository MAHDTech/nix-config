{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    wakatime-cli
  ];
}
