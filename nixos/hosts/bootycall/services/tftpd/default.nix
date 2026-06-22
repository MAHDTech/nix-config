_: {
  # TFTP Server Configuration
  services.tftpd = {
    # TODO: netkit-tftp fails to cross-compile from x86_64 to aarch64.
    # Enable this locally on the CloudKey once the system is installed natively!
    enable = false;
    path = "/mnt/hdd/tftpboot";
  };
}
