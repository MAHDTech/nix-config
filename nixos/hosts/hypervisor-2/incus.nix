let
  # Flag to indicate if the cluster has been bootstrapped.
  # Set to true once the member has joined the cluster.
  bootstrapped = true;

  # The name of the hypervisor.
  hypervisorName = "HYPERVISOR-2";

  # The role the hypervisor is playing in the cluster.
  hypervisorRole = "member";

  # The address of the hypervisor.
  hypervisorManagementAddress = "10.10.1.12:8443";
  hypervisorClusterAddress = "10.10.200.12:9443";

  # ZFS dataset sources.
  sourceDefault = "zpool/var/lib/incus/storage-pools/default";
  sourceInstances = "zpool/var/lib/incus/storage-pools/instances";
  sourceIso = "zpool/var/lib/incus/storage-pools/iso";

  # TODO: SOPS encryption when this test is working.
  # The cluster token obtained during the bootstrap process. Only used if bootstrapped is true.
  clusterToken = "eyJzZXJ2ZXJfbmFtZSI6IkhZUEVSVklTT1ItMiIsImZpbmdlcnByaW50IjoiMTFhNGViNTA3NmJhZmE0MDQ4NTkwYTNmYWNiODM5ZWEzOGU1NmEwNjg5ZGE3Y2VlYWE5YjZkMmQzMGYzMzMxYSIsImFkZHJlc3NlcyI6WyIxMC4xMC4yMDAuMTE6OTQ0MyJdLCJzZWNyZXQiOiJmZjJjNmI1NTA3ZGNlYzhlNmJhMTFmNzNkYzJlNjkxMDJjN2ZlNzEwOTg5MmYzNzE4OWMwYzAzYzNhNjRhNGYzIiwiZXhwaXJlc19hdCI6IjIwMjUtMDctMjRUMTk6MjA6MDkuMDE0OTMyODg2KzEwOjAwIn0=";
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
