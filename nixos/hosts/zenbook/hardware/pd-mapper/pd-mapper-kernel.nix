_: {
  # In-kernel Protection Domain Mapper (CONFIG_QCOM_PD_MAPPER)
  #
  # Available since Linux 6.11. Uses static per-platform mapping data compiled
  # into the kernel source — does NOT read .jsn files from the filesystem.
  # Auto-loads via symbol dependency when remoteproc drivers need it,
  # completely eliminating the boot race condition.
  #
  # When using this, the qcom_q6v5_pas blacklist, qcom-remoteproc-load service,
  # and qcom-remoteproc-start service in hardware-configuration.nix can be removed.
  # DSP modules load naturally via udev.
  #
  # NOTE: Some distributions have reported regressions on specific SoCs.
  # Test carefully on X1E80100 before switching from the userspace pd-mapper.
  boot.kernelModules = [ "qcom_pd_mapper" ];
}
