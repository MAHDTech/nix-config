{
  config,
  pkgs,
  ...
}: {

  services = {
    libinput = {
      enable = true;
    };
  };

}
