{ pkgs, ... }:
let
  # pd-mapper: Protection Domain Mapper for Qualcomm DSPs
  # Reads .jsn subsystem descriptor files and publishes Protection Domain
  # service registrations over QRTR so DSP clients can locate their subsystems.
  #
  # Status of DSP subsystems (qcom_q6v5_pas):
  #   CDSP boots successfully. ADSP boots successfully.
  #   qcom_q6v5_pas is currently blacklisted due to an NVMe/PCIe power domain
  #   conflict that occurs during DSP init — the NVMe drops off the bus, causing
  #   a filesystem crash. This is a known bring-up issue on x1e80100 and is being
  #   investigated. The blacklist is set in hardware-configuration.nix.
  #
  # pd-mapper is kept configured and ready for when the NVMe conflict is resolved.
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

  # PD Mapper service: reads .jsn subsystem descriptors and registers protection
  # domains over QRTR so clients (WiFi, audio, Bluetooth) can locate DSP services.
  #
  # Bug fixes applied vs. original implementation:
  # 1. zstd symlink bug: NixOS firmware files under /run/current-system/firmware/
  #    are symlinks (and often symlinks-to-symlinks) into the Nix store. `zstd -d`
  #    silently skips symlinks, producing empty output. Fix: resolve with readlink -f
  #    before decompressing.
  # 2. pd-mapper search path: the binary reads .jsn files from the path reported by
  #    /sys/module/firmware_class/parameters/path (defaults to /lib/firmware).
  #    We set that kernel parameter to /var/lib/pd-mapper where we stage the files,
  #    ensuring the binary finds them without patching.
  # 3. qrtr-ns removed: the kernel handles QRTR natively since 5.15. Running the
  #    userspace qrtr-ns daemon causes a "nameserver already running" conflict and
  #    pd-mapper fails to register. Confirmed on live device.
  systemd.services.pd-mapper = {
    description = "Qualcomm Protection Domain Mapper";
    documentation = [ "https://github.com/linux-msm/pd-mapper" ];
    wantedBy = [ "basic.target" ];
    after = [ "systemd-udev-trigger.service" ];

    preStart = ''
      mkdir -p /var/lib/pd-mapper

      # Decompress .jsn.zst files from the NixOS firmware tree into /var/lib/pd-mapper/.
      # IMPORTANT: Use readlink -f to resolve Nix store symlinks before calling zstd.
      # zstd silently skips symlinks without --force, producing no output.
      if [ -d /run/current-system/firmware ]; then
        find /run/current-system/firmware -name "*.jsn.zst" | while read -r f; do
          real=$(${pkgs.coreutils}/bin/readlink -f "$f")
          outname=$(basename "$f" .zst)
          ${pkgs.zstd}/bin/zstd -d -c "$real" > "/var/lib/pd-mapper/$outname" 2>/dev/null \
            && echo "pd-mapper: staged $outname" \
            || echo "pd-mapper: failed to decompress $real"
        done
        # Copy any uncompressed .jsn files directly
        find /run/current-system/firmware -name "*.jsn" | while read -r f; do
          cp -f "$f" /var/lib/pd-mapper/
        done
      fi

      # Point the kernel firmware loader at our staging directory so pd-mapper
      # finds the .jsn files via /sys/module/firmware_class/parameters/path.
      if [ -f /sys/module/firmware_class/parameters/path ]; then
        echo -n "/var/lib/pd-mapper" > /sys/module/firmware_class/parameters/path \
          || true
      fi
    '';

    serviceConfig = {
      ExecStart = "${pd-mapper}/bin/pd-mapper";
      Restart = "on-failure";
      RestartSec = "5";
      # Limit restart attempts — if DSPs are blacklisted, pd-mapper has nothing to do
      StartLimitIntervalSec = "60";
      StartLimitBurst = "3";
    };
  };
}
