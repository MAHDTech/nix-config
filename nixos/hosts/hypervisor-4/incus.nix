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
    managementAddress = "10.10.100.14:8443";

    # The incus cluster address.
    clusterAddress = "10.10.200.14:9443";

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
  # ZFS configuration.
  ################################

  zfs = {
    sourceDefault = "zpool/var/lib/incus/storage-pools/default";
    sourceInstances = "zpool/var/lib/incus/storage-pools/instances";
    sourceIso = "zpool/var/lib/incus/storage-pools/iso";
  };
in
{
  imports = [
    (import ../../system/config/virtualisation/incus {
      inherit hypervisor;
      inherit incus;
      inherit ovn;
      inherit zfs;
    })
  ];
}
