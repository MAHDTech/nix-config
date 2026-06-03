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
  # 3. Remove qrtr-ns userspace service: kernel handles QRTR natively since 5.15.
  #    Confirmed on live device: Address already in use error means pd-mapper
  #    cannot register services. Removing the userspace service resolves the
  #    QRTR nameserver conflict.
  # 4. add -L to find: NixOS firmware dir entries are symlinks. Without -L,
  #    find returns 0 results (confirmed on live device: 0 without -L, 100 with).
  # 5. pd-mapper reads /sys/class/remoteproc to discover DSP instances. With
  #    qcom_q6v5_pas blacklisted, /sys/class/remoteproc is empty and pd-mapper
  #    exits immediately with 'no pd maps available'. This is expected — guard
  #    with ConditionPathIsDirectory so the service is a no-op when DSPs are off.
  systemd.services.pd-mapper = {
    description = "Qualcomm Protection Domain Mapper";
    documentation = [ "https://github.com/linux-msm/pd-mapper" ];
    wantedBy = [ "basic.target" ];
    after = [ "systemd-udev-trigger.service" ];
    # Wait for the remoteproc subsystem to be created by the driver.
    # If the specific remoteproc devices are not yet registered,
    # the service will exit and restart automatically.
    unitConfig.ConditionPathIsDirectory = "/sys/class/remoteproc";

    preStart = ''
      # Clean up the old directory to ensure a clean slate
      rm -rf /var/lib/pd-mapper
      mkdir -p /var/lib/pd-mapper

      # Recreate the qcom directory structure as real, writable directories.
      # Only qcom/ contains .jsn files, so we only need qcom/ subdirectories to be
      # writable. Other directories (like intel, rockchip) can remain read-only symlinks.
      if [ -d /run/current-system/firmware/qcom ]; then
        find -L /run/current-system/firmware/qcom -type d | while read -r d; do
          relpath=''${d#/run/current-system/firmware/}
          mkdir -p "/var/lib/pd-mapper/$relpath"
        done
      fi

      # Link all files recursively. Since qcom directories already exist as real
      # directories, cp -as will merge inside them and link individual files, while
      # linking other non-qcom top-level directories directly as directory symlinks.
      if [ -d /run/current-system/firmware ]; then
        cp -as /run/current-system/firmware/* /var/lib/pd-mapper/
        # Make the staged tree writable so we can delete/write files inside qcom/
        chmod -R +w /var/lib/pd-mapper/qcom

        # Decompress .jsn.zst files from the NixOS firmware tree into /var/lib/pd-mapper/
        find -L /run/current-system/firmware/qcom -name "*.jsn.zst" | while read -r f; do
          real=$(${pkgs.coreutils}/bin/readlink -f "$f")
          relpath=''${f#/run/current-system/firmware/}
          outname=''${relpath%.zst}
          # Remove the symlinks created by cp -as to prevent writing through them
          rm -f "/var/lib/pd-mapper/$outname"
          rm -f "/var/lib/pd-mapper/$relpath"
          ${pkgs.zstd}/bin/zstd -d -c "$real" > "/var/lib/pd-mapper/$outname" 2>/dev/null \
            && echo "pd-mapper: staged $outname" \
            || echo "pd-mapper: failed to decompress $real"
        done

        # Copy any uncompressed .jsn files directly, preserving subdirectories
        find -L /run/current-system/firmware/qcom -name "*.jsn" | while read -r f; do
          real=$(${pkgs.coreutils}/bin/readlink -f "$f")
          relpath=''${f#/run/current-system/firmware/}
          # Remove the symlink created by cp -as to prevent writing through it
          rm -f "/var/lib/pd-mapper/$relpath"
          ln -sf "$real" "/var/lib/pd-mapper/$relpath"
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
      # Restart on failure to handle asynchronous remoteproc driver registration on boot.
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
}
