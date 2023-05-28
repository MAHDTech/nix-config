{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.thermald = {enable = true;};
}
