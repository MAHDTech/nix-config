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

let
  stdenvSystem = stdenv.hostPlatform.system;

  # Map Nix systems to LiteRT-LM binary suffixes
  systemMap = {
    "x86_64-linux" = {
      suffix = "x86_64";
      hash = "sha256-ZmAd+KB/CCRLGI6fyrC/ShZWL+dtjUfkn0AnPVdUHug=";
    };
    "aarch64-linux" = {
      suffix = "arm64";
      hash = "sha256-O8xUVHzjOd3C7zh5cfJzI4uNTBWbovRqFFmVYgmPGxo=";
    };
  };

  sysInfo = systemMap.${stdenvSystem} or (throw "Unsupported system: ${stdenvSystem}");
in

stdenv.mkDerivation rec {
  pname = "litert-lm";
  version = "0.9.0-alpha03";

  src = fetchurl {
    url = "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v${version}/lit.linux_${sysInfo.suffix}";
    inherit (sysInfo) hash;
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

    cp $src $out/libexec/lit.linux_${sysInfo.suffix}
    chmod +x $out/libexec/lit.linux_${sysInfo.suffix}

    makeWrapper $out/libexec/lit.linux_${sysInfo.suffix} $out/bin/litert-lm \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    ln -s $out/bin/litert-lm $out/bin/lit.linux_${sysInfo.suffix}

    runHook postInstall
  '';

  meta = {
    description = "LiteRT-LM (formerly lit) runtime binary for Gemma local inference";
    homepage = "https://github.com/google-ai-edge/LiteRT-LM";
    license = lib.licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "litert-lm";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
