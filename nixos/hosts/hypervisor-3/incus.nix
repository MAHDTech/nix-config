let
  # Flag to indicate if the hypervisor has joined the cluster.
  # Set to true once the hypervisor has joined the cluster.
  joined = true;

  # The name of the hypervisor.
  hypervisorName = "HYPERVISOR-3";

  # The role the hypervisor is playing in the cluster.
  hypervisorRole = "member";

  # Bootstrap node IP for joining the cluster
  bootstrapIP = "10.10.200.11";

  # The address of the hypervisor.
  hypervisorManagementAddress = "10.10.100.13:8443";
  hypervisorClusterAddress = "10.10.200.13:9443";
  hypervisorClusterPeerAddresses = [
    "10.10.200.11"
    "10.10.200.12"
    "10.10.200.14"
  ];

  # ZFS dataset sources.
  sourceDefault = "zpool/var/lib/incus/storage-pools/default";
  sourceInstances = "zpool/var/lib/incus/storage-pools/instances";
  sourceIso = "zpool/var/lib/incus/storage-pools/iso";

  # The cluster token is only needed for initial bootstrap.
  # Once joined, the cluster token can be removed.
  clusterToken = null;
in
{
  imports = [
    (import ../../system/config/virtualisation/incus {
      inherit bootstrapIP;
      inherit clusterToken;
      inherit hypervisorClusterAddress;
      inherit hypervisorClusterPeerAddresses;
      inherit hypervisorManagementAddress;
      inherit hypervisorName;
      inherit hypervisorRole;
      inherit joined;
      inherit sourceDefault sourceInstances sourceIso;
    })
  ];
}
