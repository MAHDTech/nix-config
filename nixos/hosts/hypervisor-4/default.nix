{
  ...
}:
{
  networking = {
    hostName = "HYPERVISOR-4";
    hostId = "def90004";
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

          # Incus cluster configuration (member server)
          cluster = {
            enabled = true;
            server_name = "HYPERVISOR-4";
            https_address = "10.10.200.14:8443";

            # TODO: Join existing cluster...
          };

        };
      };
    })

  ];
}
