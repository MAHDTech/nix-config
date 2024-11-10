{pkgs, ...}: {
  # https://nixos.wiki/wiki/Laptop

  imports = [];

  environment.systemPackages = with pkgs; [
    # Install powertop for analysis but not run autotune.
    powertop
  ];

  powerManagement = {
    enable = true;

    # Enabling powertop will enable autotune.
    powertop.enable = false;

    cpuFreqGovernor = "ondemand";

    resumeCommands = ''
      echo "Resuming from suspend..."
    '';
  };
}
