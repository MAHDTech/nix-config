let
  # Flag to indicate if the cluster has been bootstrapped.
  # Set to true when prompted by the bootstrap script.
  bootstrapped = false;

  # Flag to indicate if the hypervisor has joined the cluster.
  # Set to true once the hypervisor has joined the cluster.
  joined = false;

  # The name of the hypervisor.
  hypervisorName = "HYPERVISOR-2";

  # The role the hypervisor is playing in the cluster.
  hypervisorRole = "member";

  # The address of the hypervisor.
  hypervisorManagementAddress = "10.10.100.12:8443";
  hypervisorClusterAddress = "10.10.200.12:9443";

  # ZFS dataset sources.
  sourceDefault = "zpool/var/lib/incus/storage-pools/default";
  sourceInstances = "zpool/var/lib/incus/storage-pools/instances";
  sourceIso = "zpool/var/lib/incus/storage-pools/iso";

  # TODO: SOPS encryption when this test is working.
  # The cluster token obtained during the bootstrap process. Only used if bootstrapped is true.
  clusterToken = "eyJzZXJ2ZXJfbmFtZSI6IkhZUEVSVklTT1ItMiIsImZpbmdlcnByaW50IjoiNzFmMDhlZGZhNDFiMDBiYmZkNThkZmZkYzllOTg3M2QzM2E1NDljMzAxNjdhZTc0MjRjYzZjZTUzZTVmYmIwMiIsImFkZHJlc3NlcyI6WyIxMC4xMC4yMDAuMTE6OTQ0MyJdLCJzZWNyZXQiOiJjYzkzMWMyMGE1YWVjZWIwYzdmNzQyYzkxZmNiYmUyZDA2NDgyNTUwZGU1YTYzZmMyYWQwOGM3ZDU1MjM1YjEwIiwiZXhwaXJlc19hdCI6IjIwMjUtMDctMjVUMTI6NTU6NDEuNzEyNTYxMTkrMTA6MDAifQ==";
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
