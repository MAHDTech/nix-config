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
            "core.https_address" = "10.10.1.11:8443";
          };

          # Incus cluster configuration (bootstrap server)
          cluster = {
            enabled = true;
            server_name = "HYPERVISOR-1";
          };

        };
      };
    })

  ];
}
