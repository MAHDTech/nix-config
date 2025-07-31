let

  ################################
  # Hypervisor configuration.
  ################################

  hypervisor = {
    name = "HYPERVISOR-1";
  };

  ################################
  # Incus configuration.
  ################################

  incus = {
    # Flag to indicate if the hypervisor has joined the incus cluster.
    joined = true;

    # The incus server role.
    role = "bootstrap";

    # The incus management address.
    managementAddress = "10.10.100.11:8443";

    # The incus cluster address.
    clusterAddress = "10.10.200.11:9443";

    # The bootstrap server never needs a cluster token.
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
