let
  # Flag to indicate if the cluster has been bootstrapped.
  # Set to true once the member has joined the cluster.
  bootstrapped = false;

  # The name of the hypervisor.
  hypervisorName = "HYPERVISOR-4";

  # The role the hypervisor is playing in the cluster.
  hypervisorRole = "member";

  # The address of the hypervisor.
  hypervisorManagementAddress = "10.10.100.14:8443";
  hypervisorClusterAddress = "10.10.200.14:9443";

  # ZFS dataset sources.
  sourceDefault = "zpool/var/lib/incus/storage-pools/default";
  sourceInstances = "zpool/var/lib/incus/storage-pools/instances";
  sourceIso = "zpool/var/lib/incus/storage-pools/iso";

  # TODO: SOPS encryption when this test is working.
  # The cluster token obtained during the bootstrap process. Only used if bootstrapped is true.
  clusterToken = "";
in
{
  imports = [
    (import ../../system/config/virtualisation/incus {
      inherit bootstrapped;
      inherit hypervisorName;
      inherit hypervisorRole;
      inherit hypervisorManagementAddress;
      inherit hypervisorClusterAddress;
      inherit sourceDefault sourceInstances sourceIso;
      inherit clusterToken;
    })
  ];
}
