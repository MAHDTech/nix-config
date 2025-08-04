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
      enable = false;
      bind = "0.0.0.0";
      port = 3370;

      database = {
        type = "h2";
      };
    };

    #########################################################
    # Satellite (Storage provider)
    #########################################################

    satellite = {
      enable = false;
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

    # ZFS Dataset for LINSTOR
    "/var/lib/linstor" = {
      device = "zpool/var/lib/linstor";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    # ZFS Dataset for LINSTOR storage pools
    "/var/lib/linstor/storage-pools" = {
      device = "zpool/var/lib/linstor/storage-pools";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };
  };

}
