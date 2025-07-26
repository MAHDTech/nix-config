let
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
  clusterToken = "eyJzZXJ2ZXJfbmFtZSI6IkhZUEVSVklTT1ItMiIsImZpbmdlcnByaW50IjoiZTc1ZjZmMWVhMTEwNTg5NDkzOTE0ZjY4NDRlZDYwMGEzNzc5OTU3ODFkYWZiZDIzNzBlYTUyZmM3NzZjZGNkOSIsImFkZHJlc3NlcyI6WyIxMC4xMC4yMDAuMTE6OTQ0MyJdLCJzZWNyZXQiOiJmODE2YTA4YjAxZmE0OGE1Yjk0MDQ5OTIwYzgzMzk1NThiNWNlYTBiNDRkZTI5ZTRiZjRhZGUzNDhiYTNlMTcwIiwiZXhwaXJlc19hdCI6IjIwMjUtMDctMjdUMDM6MjU6MDAuNTYwMjk4MDQzKzEwOjAwIn0=";
in
{
  imports = [
    (import ../../system/config/virtualisation/incus {
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
