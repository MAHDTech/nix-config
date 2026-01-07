{
  networking.hosts = {

    "127.0.0.1" = [
      #########################
      # KinD
      # Ingress/Gateway API exposed services from local KinD cluster.
      #########################

      # KubeTail
      "kubetail.ping-devops.kind.local"

      # PING Identity
      "pingaccess-admin.ping-devops.kind.local"
      "pingaccess-engine.ping-devops.kind.local"
      "pingauthorize.ping-devops.kind.local"
      "pingauthorizepap.ping-devops.kind.local"
      "pingcentral.ping-devops.kind.local"
      "pingdataconsole.ping-devops.kind.local"
      "pingdatasync.ping-devops.kind.local"
      "pingdelegator.ping-devops.kind.local"
      "pingdirectory.ping-devops.kind.local"
      "pingdirectoryproxy.ping-devops.kind.local"
    ];

  };

}
