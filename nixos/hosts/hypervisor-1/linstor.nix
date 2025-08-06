{ pkgs, ... }:
{
  imports = [
    ../../system/config/storage/linstor
  ];

  #########################################################
  # LINSTOR Configuration
  #########################################################

  services.linstor = {

    #########################################################
    # Controller (Primary controller node)
    #########################################################

    controller = {
      enable = true;
      bind = "0.0.0.0";
      port = 3370;
      portSecure = 3371;

      database = {
        type = "h2";
      };
    };

    #########################################################
    # Satellite (Storage provider)
    #########################################################

    satellite = {
      enable = true;
      bind = "0.0.0.0";
      port = 3366;
      controllerEndpoint = "linstor://localhost:3370";
    };
  };

  #########################################################
  # Networking
  #########################################################

  networking.firewall = {
    allowedTCPPorts = [
      3366 # LINSTOR Satellite
      3370 # LINSTOR Controller
      3371 # LINSTOR Controller (secure)
    ];

    # Allow DRBD port range (7000-7999)
    allowedTCPPortRanges = [
      {
        from = 7000;
        to = 7999;
      }
    ];
  };

  #########################################################
  # Storage Dependencies
  #########################################################

  # Ensure DRBD module is loaded (required for LINSTOR)
  boot.kernelModules = [ "drbd" ];

  # Install DRBD utilities
  environment.systemPackages = with pkgs; [
    drbd
  ];

  #########################################################
  # ZFS Datasets for LINSTOR
  #########################################################

  fileSystems = {

    # ZFS Dataset for LINSTOR Data
    "/var/lib/linstor" = {
      device = "zpool/var/lib/linstor";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    # ZFS Dataset for LINSTOR Metadata
    "/var/lib/linstor.d" = {
      device = "zpool/var/lib/linstor.d";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };
  };

}
