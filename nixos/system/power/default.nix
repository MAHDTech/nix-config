{pkgs, ...}: {
  imports = [];

  environment.systemPackages = with pkgs; [];

  powerManagement = {
    enable = true;

    # Enabling powertop will enable autotune.
    powertop = {enable = false;};

    cpuFreqGovernor = "performance";

    resumeCommands = ''
      echo "Resuming from suspend..."
    '';
  };
}
