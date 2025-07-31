let

  # Common configuration used across Incus and OVN.
  hypervisor = {
    name = "HYPERVISOR-1";
    role = "bootstrap";
    managementAddress = "10.10.100.11:8443";
    clusterAddress = "10.10.200.11:9443";
    clusterPeerAddresses = [
      "10.10.200.12"
      "10.10.200.13"
      "10.10.200.14"
    ];
  };

  # Incus configuration.
  incus = {
    # Flag to indicate if the hypervisor has joined the incus cluster.
    joined = false;

    # The bootstrap server never needs a cluster token.
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
