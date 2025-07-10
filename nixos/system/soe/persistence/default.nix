##################################################
# Persistence
#   https://nixos.wiki/wiki/Impermanence
##################################################

{ _ }:

let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{

  imports = [ "${impermanence}/nixos.nix" ];

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

      # The dreaded systemd error "unsupported enviment where /usr/ is not populated"
      "/usr/"

      # Bluetooth configuration
      "/var/lib/bluetooth"
    ];

  };

}
