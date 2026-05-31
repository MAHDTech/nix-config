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
    rev = "main";
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
    description = "Proprietary firmware binary blobs for CIX Sky1 SoC subsystems (VPU, GPU, DSP, WiFi)";
    homepage = "https://github.com/Sky1-Linux/sky1-firmware";
    license = licenses.unfreeRedistributable;
    platforms = [ "aarch64-linux" ];
  };
}
