{ ... }:
{
  imports = [
    # In-kernel pd-mapper (CONFIG_QCOM_PD_MAPPER) — disabled.
    # Not yet reliable on X1E80100; using userspace pd-mapper instead.
    #./pd-mapper-kernel.nix

    # Use the userspace pd-mapper services
    ./pd-mapper-service.nix
  ];
}
