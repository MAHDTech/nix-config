{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.acpid = {enable = true;};
}
