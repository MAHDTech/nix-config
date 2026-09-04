{ lib, ... }:
{
  programs.alacritty.settings.colors = lib.mkForce {
    primary = {
      background = "#0F0A18";
      foreground = "#F0F8FF";
    };

    cursor = {
      text = "#0F0A18";
      cursor = "#F92AAD";
    };

    selection = {
      text = "#F0F8FF";
      background = "#591E4E";
    };

    normal = {
      black = "#0F0A18";
      red = "#FE4450";
      green = "#72F1B8";
      yellow = "#FDF129";
      blue = "#2EE2FA";
      magenta = "#F92AAD";
      cyan = "#36F9F6";
      white = "#F0F8FF";
    };

    bright = {
      black = "#312447";
      red = "#FE4450";
      green = "#72F1B8";
      yellow = "#FDF129";
      blue = "#2EE2FA";
      magenta = "#F92AAD";
      cyan = "#36F9F6";
      white = "#FFFFFF";
    };
  };
}
