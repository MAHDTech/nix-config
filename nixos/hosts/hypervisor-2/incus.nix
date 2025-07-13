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
            "core.https_address" = "10.10.1.12:8443";
          };

          # Incus cluster configuration (member server)
          cluster = {
            enabled = true;
            server_name = "HYPERVISOR-2";

            server_address = "hypervisor-1.saltlabs.cloud:8443";
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
