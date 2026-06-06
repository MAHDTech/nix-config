{ pkgs, ... }:
{
  # https://nixos.wiki/wiki/Laptop

  imports = [ ];

  environment.systemPackages = with pkgs; [
    # Install powertop for analysis but not run autotune.
    powertop
  ];

  powerManagement = {
    enable = true;

    # Don't enable powertop as it auto-enables autotune.
    powertop.enable = false;

    resumeCommands = ''
      echo "Resuming from suspend..."
    '';
  };
}
