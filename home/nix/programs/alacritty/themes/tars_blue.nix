{ lib, ... }:
{
  programs.alacritty.settings.colors = lib.mkForce {
    primary = {
      background = "#05101F";
      foreground = "#CCD6F6";
    };

    cursor = {
      text = "#05101F";
      cursor = "#00E5FF";
    };

    selection = {
      text = "#CCD6F6";
      background = "#043A4B";
    };

    normal = {
      black = "#05101F";
      red = "#FF2A2A";
      green = "#00FF66";
      yellow = "#FFD700";
      blue = "#00E5FF";
      magenta = "#FF4D8C";
      cyan = "#00E5FF";
      white = "#CCD6F6";
    };

    bright = {
      black = "#5B759F";
      red = "#FF2A2A";
      green = "#00FF66";
      yellow = "#FFD700";
      blue = "#00E5FF";
      magenta = "#FF4D8C";
      cyan = "#00E5FF";
      white = "#FFFFFF";
    };
  };
}
