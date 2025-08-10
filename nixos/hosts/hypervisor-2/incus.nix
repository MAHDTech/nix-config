let

  ################################
  # Hypervisor configuration.
  ################################

  hypervisor = {
    name = "HYPERVISOR-2";
  };

  ################################
  # Incus configuration.
  ################################

  incus = {
    # Flag to indicate if the hypervisor has joined the incus cluster.
    joined = true;

    # The incus server role.
    role = "member";

    # The incus management address.
    management = {
      address = "10.10.100.12";
      port = 8443;
    };

    # The incus cluster address.
    cluster = {
      address = "10.10.200.12";
      port = 9443;
    };

    # The cluster token is only needed for initial bootstrap.
    # Once joined, the cluster token can be removed.
    clusterToken = null;
  };

  ################################
  # OVN configuration.
  ################################

  ovn = {
    # Flag to indicate if the hypervisor has joined the ovn cluster.
    joined = true;

    # IP addresses of all OVN cluster members.
    clusterAddresses = [
      "10.10.200.11"
      "10.10.200.12"
      "10.10.200.13"
      "10.10.200.14"
    ];
  };

  ################################
  # LINSTOR configuration.
  ################################

  linstor = {
    enabled = true;
    storagePool = "linstor";
    controller = {
      connection = "http://10.10.200.11:3370";
    };
  };

in
{
  imports = [
    (import ../../system/config/virtualisation/incus {
      inherit hypervisor;
      inherit incus;
      inherit ovn;
      inherit linstor;
    })
  ];

  fileSystems = {
    # Legacy mount point for var/lib/incus using ZFS
    "/var/lib/incus" = {
      device = "zpool/var/lib/incus";
      fsType = "zfs";
      options = [
        "zfsutil"
      ];
      neededForBoot = false;
    };
  };
}
