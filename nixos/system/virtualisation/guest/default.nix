{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  virtualisation = {
    vmware = {
      guest = {
        enable = false;

        headless = false;
      };
    };
  };
}
