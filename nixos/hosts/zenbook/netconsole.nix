{ pkgs, ... }:
{
  # Netconsole: remote kernel crash capture over UDP
  #
  # Sends kernel panic/oops output to JONS (10.10.1.97:6666) where a
  # ncat receiver logs it to /var/log/netconsole-zenbook.log.
  #
  # Loaded as a late systemd service because the USB-ethernet adapter (enu2c2)
  # needs DHCP before netconsole can bind. Early-boot panics are covered by
  # ramoops (DTB overlay) and pstore-blk (dedicated partition) instead.
  systemd.services.netconsole = {
    description = "Load netconsole for remote crash capture";
    after = [
      "network-online.target"
      "sys-subsystem-net-devices-enu2c2.device"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "start-netconsole" ''
        SRC_IP=$(${pkgs.iproute2}/bin/ip -4 addr show enu2c2 | ${pkgs.gnugrep}/bin/grep -oP 'inet \K[\d.]+')
        if [ -z "$SRC_IP" ]; then
          echo "netconsole: enu2c2 has no IP, skipping"
          exit 0
        fi
        ${pkgs.kmod}/bin/modprobe netconsole "netconsole=@$SRC_IP/enu2c2,6666@10.10.1.97/"
        echo "netconsole: configured with source IP $SRC_IP → 10.10.1.97:6666"
      '';
      ExecStop = "${pkgs.kmod}/bin/modprobe -r netconsole";
    };
  };
}
