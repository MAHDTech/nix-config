{ pkgs, ... }:
let
  # pd-mapper: Protection Domain Mapper for Qualcomm DSPs
  # Required for WiFi, Bluetooth, and Audio on Snapdragon X Elite
  pd-mapper = pkgs.stdenv.mkDerivation {
    pname = "pd-mapper";
    version = "1.1";

    src = pkgs.fetchFromGitHub {
      owner = "linux-msm";
      repo = "pd-mapper";
      rev = "v1.1";
      sha256 = "sha256-I5/N24KONtNRSub00Mqh1GoMHO2qQKTj/ts2N6DQdPc=";
    };

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.qrtr
      pkgs.xz
    ];

    installPhase = ''
      mkdir -p $out/bin
      cp pd-mapper $out/bin/
    '';

    meta = with pkgs.lib; {
      description = "Qualcomm Protection Domain Mapper";
      homepage = "https://github.com/linux-msm/pd-mapper";
      license = licenses.bsd3;
      platforms = platforms.linux;
    };
  };
in
{
  boot.kernelModules = [ "qcom_pd_mapper" ];

  # PD Mapper service is critical for firmware loading on DSPs
  systemd.services.pd-mapper = {
    description = "Qualcomm Protection Domain Mapper";
    documentation = [ "https://github.com/linux-msm/pd-mapper" ];
    wantedBy = [ "basic.target" ];
    after = [
      "qrtr-ns.service"
      "systemd-udev-trigger.service"
    ];
    requires = [ "qrtr-ns.service" ];

    preStart = ''
      mkdir -p /var/lib/pd-mapper
      # NixOS compresses firmware files to *.zst by default. Since pd-mapper is a C daemon
      # that doesn't understand zstd-compressed mapping files, we decompress them to /var/lib/pd-mapper/
      # so that pd-mapper can find and read the subsystem descriptors correctly.
      if [ -d /run/current-system/firmware ]; then
        find /run/current-system/firmware -name "*.jsn.zst" -exec sh -c '
          for f; do
            outname=$(basename "$f" .zst)
            ${pkgs.zstd}/bin/zstd -d -c "$f" > "/var/lib/pd-mapper/$outname"
          done
        ' _ {} +
        find /run/current-system/firmware -name "*.jsn" -exec cp -f {} /var/lib/pd-mapper/ \;
      fi
    '';

    serviceConfig = {
      ExecStart = "${pd-mapper}/bin/pd-mapper";
      Restart = "always";
      RestartSec = "1";
    };
  };

  # QRTR Name Service is also required
  systemd.services.qrtr-ns = {
    description = "Qualcomm IPC Router Name Service";
    wantedBy = [ "basic.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.qrtr}/bin/qrtr-ns 1";
      Restart = "always";
    };
  };
}
