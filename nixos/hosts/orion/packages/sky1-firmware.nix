{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "sky1-firmware";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "Sky1-Linux";
    repo = "sky1-firmware";
    # Pinned to specific commit SHA for reproducibility — update with date comment when bumping
    # Latest verified: 2026-02-10 — "UCM2: add 5th HDMI/DP output and fix formatting"
    rev = "dd81690747ddb092bcc2a221daa0f8f679ee4bc4"; # 2026-02-10
    hash = "sha256-c2s3SITkTx9uXOd5yn7RDI+ahrtDSsLzlX8AAcf83Mo=";
  };

  # Proprietary pre-compiled binaries - skip configure and build phases
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/firmware
    cp -r * $out/lib/firmware/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Proprietary firmware blobs for CIX Sky1 SoC: Mali GPU, VPU codecs, HiFi5 DSP, and HDMI/DP UCM2 audio profiles. NOTE: PCIe WiFi on Orion O6 is Intel AX210 (iwlwifi from linux-firmware), not covered here.";
    homepage = "https://github.com/Sky1-Linux/sky1-firmware";
    license = licenses.unfreeRedistributable;
    platforms = [ "aarch64-linux" ];
  };
}
