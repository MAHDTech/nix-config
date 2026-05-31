{
  stdenv,
  lib,
  fetchurl,
  dpkg,
  autoPatchelfHook,
}:

stdenv.mkDerivation rec {
  pname = "cix-noe-umd";
  version = "2.0.2";

  src = fetchurl {
    url = "https://github.com/radxa-pkg/cix-prebuilt/releases/download/rc3.3-2601/cix-noe-umd_${version}_arm64.deb";
    hash = "sha256-aWvH62Bi2htc+mDbrC4DDY4UWmiSTIVuKRfvZZFAoyg=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++.so.6
  ];

  # Extract debian archive directly instead of standard unpack
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  # Organize files into standard Nix store paths
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin $out/include

    # 1. Install userspace shared libraries (libnoe.so)
    if [ -d usr/lib ]; then
      cp -r usr/lib/* $out/lib/
    fi
    if [ -d lib ]; then
      cp -r lib/* $out/lib/
    fi

    # 2. Install userspace helper binaries (e.g. cix-npu-top)
    if [ -d usr/bin ]; then
      cp -r usr/bin/* $out/bin/
    fi

    # 3. Install NPU SDK Headers
    if [ -d usr/include ]; then
      cp -r usr/include/* $out/include/
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "CIX NPU Userspace Media Driver (cix-noe-umd)";
    homepage = "https://radxa.com";
    license = licenses.unfreeRedistributable;
    platforms = [ "aarch64-linux" ];
  };
}
