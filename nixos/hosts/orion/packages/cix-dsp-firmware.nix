{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "cix-dsp-firmware";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/cixtech/cix_proprietary__cix_proprietary/raw/refs/heads/cix_p1_k6.6_master/cix_proprietary-debs/cix-audio-dsp/usr/lib/firmware/dsp_fw.bin";
    hash = "sha256-FQ4BBHqEKpqlQbf852qWVavoAWHeVBaiyQdaBNLlFAg=";
  };

  # Proprietary raw binary - skip unpack, configure, and build phases
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/firmware
    cp $src $out/lib/firmware/dsp_fw.bin

    runHook postInstall
  '';

  meta = with lib; {
    description = "Proprietary DSP firmware binary blob for CIX P1 Audio subsystem";
    homepage = "https://github.com/cixtech/cix_proprietary__cix_proprietary";
    license = licenses.unfreeRedistributable;
    platforms = [ "aarch64-linux" ];
  };
}
