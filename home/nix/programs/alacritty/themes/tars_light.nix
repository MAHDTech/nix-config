{ lib, ... }:
{
  programs.alacritty.settings.colors = lib.mkForce {
    primary = {
      background = "#F5F8F8";
      foreground = "#0B0E14";
    };

    cursor = {
      text = "#F5F8F8";
      cursor = "#00808B";
    };

    selection = {
      text = "#0B0E14";
      background = "#C4E0E2";
    };

    normal = {
      black = "#F5F8F8";
      red = "#DC143C";
      green = "#00A040";
      yellow = "#B8860B";
      blue = "#00808B";
      magenta = "#D000BA";
      cyan = "#00808B";
      white = "#0B0E14";
    };

    bright = {
      black = "#647A8F";
      red = "#DC143C";
      green = "#00A040";
      yellow = "#B8860B";
      blue = "#00808B";
      magenta = "#D000BA";
      cyan = "#00808B";
      white = "#000000";
    };
  };
}
