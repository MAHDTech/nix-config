{
  # Allow AppImages to work.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
