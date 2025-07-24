let
  # Flag to indicate if the cluster has been bootstrapped.
  # Set to true once all members have joined the cluster.
  bootstrapped = false;

  # The name of the hypervisor.
  hypervisorName = "HYPERVISOR-1";

  # The role the hypervisor is playing in the cluster.
  hypervisorRole = "bootstrap";

  # The address of the hypervisor.
  hypervisorManagementAddress = "10.10.1.11:8443";
  hypervisorClusterAddress = "10.10.200.11:9443";

  # ZFS dataset sources.
  sourceDefault = "zpool/var/lib/incus/storage-pools/default";
  sourceInstances = "zpool/var/lib/incus/storage-pools/instances";
  sourceIso = "zpool/var/lib/incus/storage-pools/iso";
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
    })
  ];
}
