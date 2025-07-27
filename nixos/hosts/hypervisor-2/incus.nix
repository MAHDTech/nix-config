let
  # Flag to indicate if the hypervisor has joined the cluster.
  # Set to true once the hypervisor has joined the cluster.
  joined = true;

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
  clusterToken = "eyJzZXJ2ZXJfbmFtZSI6IkhZUEVSVklTT1ItMiIsImZpbmdlcnByaW50IjoiMjYxYTE5M2UxNzFhN2M5MDBmODA5YjE1ODdhMTg4NjkyY2M3OTRhODI1MDhkMDY4MzgzMGYyYTRmZDYxOTVhOCIsImFkZHJlc3NlcyI6WyIxMC4xMC4yMDAuMTE6OTQ0MyJdLCJzZWNyZXQiOiJjN2Q3YWFlODkxMzdkZDQ0MDMxMjNlMTM5NGQ3NTA0MGM0Y2UzZjc4YmY5ZTdmMTVhZDUzNjZlNTg0Y2MxZGRjIiwiZXhwaXJlc19hdCI6IjIwMjUtMDctMjdUMTM6MTc6NDguMjk1MTQyNzQyKzEwOjAwIn0=";
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
