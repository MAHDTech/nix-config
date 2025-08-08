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
      controllerEndpoint = "linstor://10.10.200.11:3370";
    };

    #########################################################
    # DRBD Configuration
    #########################################################

    drbd = {
      enable = true;
      extraConfig = ''
        #########################################################
        # Extra DRBD configuration for LINSTOR
        #########################################################

        # TODO: Add extra DRBD configuration here...
      '';
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

  # Storage dependencies are now handled by the main LINSTOR module

  #########################################################
  # ZFS Datasets for LINSTOR
  #########################################################

  fileSystems = {

    # ZFS Dataset for LINSTOR Data (Controller)
    "/var/lib/linstor" = {
      device = "zpool/var/lib/linstor";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    # ZFS Dataset for LINSTOR Metadata (Satellite)
    "/var/lib/linstor.d" = {
      device = "zpool/var/lib/linstor.d";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };

    # ZFS Dataset for LINSTOR Storage Pool (Satellite)
    "/var/lib/linstor/storage-pool" = {
      device = "zpool/var/lib/linstor/storage-pool";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };
  };

}
