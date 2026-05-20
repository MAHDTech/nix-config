{ pkgs, ... }:
let
  # pd-mapper: Protection Domain Mapper for Qualcomm DSPs
  # Required for WiFi, Bluetooth, and Audio on Snapdragon X Elite
  pd-mapper = pkgs.stdenv.mkDerivation {
    pname = "pd-mapper";
    version = "unstable-2025-12-30";

    src = pkgs.fetchFromGitHub {
      owner = "andersson";
      repo = "pd-mapper";
      rev = "5ecd2fe926aca7abfe40724177f63b942cff3947";
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
      homepage = "https://github.com/andersson/pd-mapper";
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
    documentation = [ "https://github.com/andersson/pd-mapper" ];
    wantedBy = [ "multi-user.target" ];
    after = [ "qrtr-ns.service" ];
    requires = [ "qrtr-ns.service" ];
    serviceConfig = {
      ExecStart = "${pd-mapper}/bin/pd-mapper";
      Restart = "always";
      RestartSec = "1";
    };
  };

  # QRTR Name Service is also required
  systemd.services.qrtr-ns = {
    description = "Qualcomm IPC Router Name Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.qrtr}/bin/qrtr-ns -f 1";
      Restart = "always";
    };
  };
}
