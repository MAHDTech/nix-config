{
  networking.hosts = {

    "127.0.0.1" = [
      #########################
      # KinD
      # Ingress/Gateway API exposed services from local KinD cluster.
      #########################

      # Test
      "test.kind.local"

      # KubeTail
      "kubetail.kind.local"

      # PING Identity
      "pingaccess-admin.kind.local"
      "pingaccess-engine.kind.local"
      "pingauthorize.kind.local"
      "pingauthorizepap.kind.local"
      "pingcentral.kind.local"
      "pingdataconsole.kind.local"
      "pingdatasync.kind.local"
      "pingdelegator.kind.local"
      "pingdirectory.kind.local"
      "pingdirectoryproxy.kind.local"
      "pingfederate-admin.kind.local"
      "pingfederate-engine.kind.local"
    ];

  };

}
