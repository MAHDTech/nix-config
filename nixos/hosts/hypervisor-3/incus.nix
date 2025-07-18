let
  # Flag to indicate if the cluster has been bootstrapped.
  bootstrapped = false;

  # The name of the hypervisor.
  hypervisorName = "HYPERVISOR-3";

  # The role the hypervisor is playing in the cluster.
  hypervisorRole = "member";

  # The address of the hypervisor.
  hypervisorManagementAddress = "10.10.1.13:8443";
  hypervisorClusterAddress = "10.10.200.13:9443";

  # ZFS dataset sources.
  sourceDefault = "zpool/var/lib/incus/storage-pools/default";
  sourceInstances = "zpool/var/lib/incus/storage-pools/instances";
  sourceIso = "zpool/var/lib/incus/storage-pools/iso";

  # TODO: SOPS encryption when this test is working.
  # The cluster token obtained during the bootstrap process. Only used if bootstrapped is true.
  clusterToken = "eyJzZXJ2ZXJfbmFtZSI6IkhZUEVSVklTT1ItMyIsImZpbmdlcnByaW50IjoiY2RjYWJkNjZkYTljZjhkNGJlODE5ZmQzMDJmNmE5OGU5MGRmZGFhYjIwOTRhZDcwZGIyMGRkMzhhMDkyYjU4NCIsImFkZHJlc3NlcyI6WyIxMC4xMC4yMDAuMTE6OTQ0MyJdLCJzZWNyZXQiOiI3MzI0NzM0NmNiOWQ1MTkxOTJjOTI2YWIxOTlkYWE5NTI5NTJiMTBhMjA0ZmM0MmZlYTU3YzdhM2ExNDI4ZWE5IiwiZXhwaXJlc19hdCI6IjIwMjUtMDctMTlUMDA6MDg6MDcuMTI3MzQxOTY5KzEwOjAwIn0=";
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
