{
  autoPatchelfHook,
  fetchurl,
  glib,
  lib,
  libGL,
  makeWrapper,
  stdenv,
  vulkan-loader,
}:

stdenv.mkDerivation rec {
  pname = "litert-lm";
  version = "0.9.0-alpha03";

  src = fetchurl {
    url = "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v${version}/lit.linux_x86_64";
    hash = "sha256-ZmAd+KB/CCRLGI6fyrC/ShZWL+dtjUfkn0AnPVdUHug=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    vulkan-loader
    libGL
    glib
    stdenv.cc.cc.lib
  ];

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec

    cp $src $out/libexec/lit.linux_x86_64
    chmod +x $out/libexec/lit.linux_x86_64

    makeWrapper $out/libexec/lit.linux_x86_64 $out/bin/litert-lm \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    ln -s $out/bin/litert-lm $out/bin/lit.linux_x86_64

    runHook postInstall
  '';

  meta = {
    description = "LiteRT-LM (formerly lit) runtime binary for Gemma local inference";
    homepage = "https://github.com/google-ai-edge/LiteRT-LM";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "litert-lm";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
