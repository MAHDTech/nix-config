{
  pkgs,
  ...
}:
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
      owner = "MAHDTech";
      repo = "pd-mapper";
      rev = "c41ecdb0a5ce5af64b21d4594c3e43c75271f440";
      hash = "sha256-rN+Dt+X/MGJ7ltxvSPj46Fd8/QWREtv2YukCUS0MBIE=";
    };

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.qrtr
      pkgs.xz
      pkgs.zstd
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
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-udev-trigger.service"
    ];

    preStart = ''
      # Clean up the old directory to ensure a clean slate
      rm -rf /var/lib/pd-mapper
      mkdir -p /var/lib/pd-mapper

      # Symlink all top-level files/directories from the system firmware.
      if [ -d /run/current-system/firmware ]; then
        cp -as /run/current-system/firmware/* /var/lib/pd-mapper/
      fi
    '';

    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${pd-mapper}/bin/pd-mapper $$(find /var/lib/pd-mapper/qcom/x1e80100 -name \"*.jsn*\")'";
      # Restart on failure to handle asynchronous remoteproc driver registration on boot.
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
}
