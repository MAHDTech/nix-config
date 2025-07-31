let

  # Common configuration used across Incus and OVN.
  hypervisor = {
    name = "HYPERVISOR-2";
    role = "member";
    managementAddress = "10.10.100.12:8443";
    clusterAddress = "10.10.200.12:9443";
    clusterPeerAddresses = [
      "10.10.200.11"
      "10.10.200.13"
      "10.10.200.14"
    ];
  };

  # Incus configuration.
  incus = {
    # Flag to indicate if the hypervisor has joined the incus cluster.
    joined = false;

    # The cluster token is only needed for initial bootstrap.
    # Once joined, the cluster token can be removed.
    clusterToken = null;
  };

  # OVN configuration.
  ovn = {
    # Flag to indicate if the hypervisor has joined the ovn cluster.
    joined = false;
  };

  # ZFS configuration.
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
