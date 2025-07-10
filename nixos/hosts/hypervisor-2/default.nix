{
  ...
}:
{
  networking = {
    hostName = "hypervisor-2";
    hostId = "def90002";
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

    # Incus
    (import ../../system/config/virtualisation/incus {
      hostConfig = {
        preseed = {

          # Incus cluster configuration (member server)
          cluster = {
            enabled = true;
            server_name = "hypervisor-2";
            https_address = "10.10.200.12:8443";
          };

        };
      };
    })

  ];
}
