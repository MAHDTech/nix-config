##################################################
# Persistence
#   https://nixos.wiki/wiki/Impermanence
##################################################

{ inputs, ... }:
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  environment.persistence."/persistent" = {
    enable = true;

    hideMounts = true;

    directories = [
      # systemd
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/timers"

      # logs
      "/var/log"

      # NixOS
      "/var/lib/nixos"

      # The dreaded systemd error "unsupported environment where /usr/ is not populated"
      "/usr/"

      # Bluetooth configuration
      "/var/lib/bluetooth"
    ];

    files = [
      "/etc/machine-id"
    ];

  };

}
