{
  ...
}:
{

  imports = [

    # Incus
    (import ../../system/config/virtualisation/incus {
      hostConfig = {
        preseed = {

          # Config
          config = {
            # Management interface.
            "core.https_address" = "10.10.1.14:8443";
          };

          # Incus cluster configuration (member server)
          cluster = {
            enabled = true;
            server_name = "HYPERVISOR-4";

            server_address = "HYPERVISOR-1.saltlabs.cloud:8443";
            cluster_token = "join-token-here";

            member_config = {
              # TODO: Add member configuration here.
            };

          };

        };
      };
    })

  ];
}
