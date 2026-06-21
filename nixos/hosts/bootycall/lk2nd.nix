{
  pkgs ? import <nixpkgs> { },
}:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "lk2nd";
  version = "0.15.0";

  src = pkgs.fetchFromGitHub {
    owner = "msm8953-mainline";
    repo = "lk2nd";
    rev = "97e15454b9aac5b48ba8bc106db66035c14106c9";
    hash = "sha256-y6u6GrLbt3bxlbkvXT8MYxsDRiBFSNes4OF+JO7jyeE=";
  };

  nativeBuildInputs = [
    pkgs.gcc-arm-embedded
    pkgs.dtc
    (pkgs.python3.withPackages (
      p: with p; [
        libfdt
        pycryptodome
        pyasn1-modules
      ]
    ))
  ];

  preBuild = ''
    patchShebangs scripts
    export LD_LIBRARY_PATH=${pkgs.dtc}/lib:$LD_LIBRARY_PATH
  '';

  makeFlags = [
    "TOOLCHAIN_PREFIX=arm-none-eabi-"
    "msm8953-secondary"
  ];

  installPhase = ''
    mkdir -p $out
    cp build-msm8953-secondary/lk2nd.img $out/
  '';
}
