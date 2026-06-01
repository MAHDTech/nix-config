{
  lib,
  stdenv,
  fetchurl,
}:

# CIX P1 Tensilica HiFi5 DSP firmware binary
# Source: github.com/cixtech/cix_proprietary__cix_proprietary
# Branch: cix_p1_k6.6_master (branch name contains "k6.6" but firmware is kernel-version-independent)
# Version: 1.0.0 (no semantic versioning in upstream repo — update hash below if the file changes)
# Required for: CIX DSP IPC driver (CONFIG_CIX_DSP=m enabled in kernel.nix)
# Future: will also be required by SND_HDA_CIX_IPBLOQ when HDMI/DP audio driver ships
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
