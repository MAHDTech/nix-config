{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  services.cron = {
    enable = true;

    systemCronJobs = [];
  };
}
