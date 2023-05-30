{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.avahi = {
    enable = true;

    nssmdns = true;

    ipv4 = true;
    ipv6 = false;

    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}
