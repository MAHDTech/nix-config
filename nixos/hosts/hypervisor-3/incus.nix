let
  # Flag to indicate if the cluster has been bootstrapped.
  # Set to true once the member has joined the cluster.
  bootstrapped = true;

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
  clusterToken = "eyJzZXJ2ZXJfbmFtZSI6IkhZUEVSVklTT1ItMyIsImZpbmdlcnByaW50IjoiMTFhNGViNTA3NmJhZmE0MDQ4NTkwYTNmYWNiODM5ZWEzOGU1NmEwNjg5ZGE3Y2VlYWE5YjZkMmQzMGYzMzMxYSIsImFkZHJlc3NlcyI6WyIxMC4xMC4yMDAuMTE6OTQ0MyJdLCJzZWNyZXQiOiJhNTRjNmQ3OGJjOTY1Nzc3NjY4MzQ0MTEyYjM4NDI3ZjZmNGQ3MTZlNTAxNjc0Njg1YzljNzg1NTNjMjk3MjQzIiwiZXhwaXJlc19hdCI6IjIwMjUtMDctMjRUMTk6MjA6MDkuMDQyOTYyNCsxMDowMCJ9";
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
