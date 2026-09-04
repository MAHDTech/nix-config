{ lib, ... }:
{
  programs.alacritty.settings.colors = lib.mkForce {
    primary = {
      background = "#0B0E14";
      foreground = "#E2F1FF";
    };

    cursor = {
      text = "#0B0E14";
      cursor = "#00F0FF";
    };

    selection = {
      text = "#E2F1FF";
      background = "#083B43";
    };

    normal = {
      black = "#0B0E14";
      red = "#FF2A2A";
      green = "#00FF66";
      yellow = "#FFD700";
      blue = "#00F0FF";
      magenta = "#FF00E6";
      cyan = "#00F0FF";
      white = "#E2F1FF";
    };

    bright = {
      black = "#647A8F";
      red = "#FF2A2A";
      green = "#00FF66";
      yellow = "#FFD700";
      blue = "#00F0FF";
      magenta = "#FF00E6";
      cyan = "#00F0FF";
      white = "#FFFFFF";
    };
  };
}
