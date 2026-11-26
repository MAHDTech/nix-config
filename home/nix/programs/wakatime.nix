{
  pkgsUnstable,
  ...
}:
{
  home.packages = with pkgsUnstable; [
    wakatime-cli
  ];
}
