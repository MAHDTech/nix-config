let
  # Flag to indicate if the cluster has been bootstrapped.
  # Set to true when prompted by the bootstrap script.
  bootstrapped = false;

  # Flag to indicate if the hypervisor has joined the cluster.
  # Set to true once the hypervisor has joined the cluster.
  joined = false;

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
  clusterToken = "eyJzZXJ2ZXJfbmFtZSI6IkhZUEVSVklTT1ItNCIsImZpbmdlcnByaW50IjoiNzFmMDhlZGZhNDFiMDBiYmZkNThkZmZkYzllOTg3M2QzM2E1NDljMzAxNjdhZTc0MjRjYzZjZTUzZTVmYmIwMiIsImFkZHJlc3NlcyI6WyIxMC4xMC4yMDAuMTE6OTQ0MyJdLCJzZWNyZXQiOiIwZDJlM2Q0Yzc3MTNhNDhkMDBhOGMwNDBiNzQ2MTFhZTg3MWIzY2EzNThhNGVhMmQwZWE3YmQwMTNlNzVkYzMzIiwiZXhwaXJlc19hdCI6IjIwMjUtMDctMjVUMTI6NTU6NDEuNzc1ODYzNzcrMTA6MDAifQ==";
in
{
  imports = [
    (import ../../system/config/virtualisation/incus {
      inherit bootstrapped;
      inherit joined;
      inherit hypervisorName;
      inherit hypervisorRole;
      inherit hypervisorManagementAddress;
      inherit hypervisorClusterAddress;
      inherit sourceDefault sourceInstances sourceIso;
      inherit clusterToken;
    })
  ];
}
