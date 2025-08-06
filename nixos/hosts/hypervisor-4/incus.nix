let

  ################################
  # Hypervisor configuration.
  ################################

  hypervisor = {
    name = "HYPERVISOR-4";
  };

  ################################
  # Incus configuration.
  ################################

  incus = {
    # Flag to indicate if the hypervisor has joined the incus cluster.
    joined = false;

    # The incus server role.
    role = "member";

    # The incus management address.
    management = {
      address = "10.10.100.14";
      port = 8443;
    };

    # The incus cluster address.
    cluster = {
      address = "10.10.200.14";
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
    joined = false;

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

    # TODO: Configure LINSTOR before enabling.
    enabled = false;

    # Resource group configuration for Incus storage pools
    resourceGroup = {
      name = "incus-rg"; # LINSTOR resource group name
      placeCount = 3; # 3 replicas across the hypervisor cluster
      storagePool = "incus"; # The LINSTOR storage pool name on satellite nodes
    };

    # Volume configuration
    volume = {
      prefix = "incus-vol-"; # Prefix for LINSTOR managed volumes
    };

    # DRBD configuration for high availability
    drbd = {
      onNoQuorum = "suspend-io"; # Suspend IO when quorum is lost
      autoDiskful = "5m"; # Auto-convert diskless to diskful after 5 minutes
      autoAddQuorumTiebreaker = true; # Allow auto tiebreakers for quorum
    };

    # Controller connection (using controller on hypervisor-1)
    controller = {
      connection = null; # Use remote controller
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
