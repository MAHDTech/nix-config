{
  ...
}:
{
  networking = {
    hostName = "HYPERVISOR-1";
    hostId = "def90001";
  };

  imports = [
    # Load hardware specific configuration.
    ./hardware-configuration.nix

    # Load system standard-operating-environment.
    ../../system/soe

    # CPU specific configuration.
    ../../system/config/virtualisation/cpu/amd.nix

    # GPU specific configuration.
    ../../system/config/video/amd

    # Storage specific configuration.
    ../../system/config/storage/zfs

    # Theme specific configuration.
    ../../system/config/theme/catppuccin

    # Incus
    (import ../../system/config/virtualisation/incus {
      hostConfig = {
        preseed = {

          # Config
          config = {
            "core.https_address" = "10.10.200.11:8443";
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
