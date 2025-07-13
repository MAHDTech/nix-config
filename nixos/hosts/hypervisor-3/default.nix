{
  ...
}:
{
  networking = {
    hostName = "HYPERVISOR-3";
    hostId = "def90003";
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

    # Network specific configuration.
    ./network.nix

    # Incus
    (import ../../system/config/virtualisation/incus {
      hostConfig = {
        preseed = {

          # Config
          config = {
            # Management interface.
            "core.https_address" = "10.10.1.13:8443";
          };

          # Incus cluster configuration (member server)
          cluster = {
            # TODO: Join existing cluster...
            server_name = "HYPERVISOR-3";
          };

        };
      };
    })

  ];
}
