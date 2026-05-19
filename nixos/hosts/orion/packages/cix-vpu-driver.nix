{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
}:

stdenv.mkDerivation rec {
  pname = "cix-vpu-driver";
  version = "mainline_dev-${kernel.version}";

  src = fetchFromGitHub {
    owner = "cixtech";
    repo = "cix_opensource__vpu_driver";
    rev = "cix_mainline_dev";
    hash = "sha256-YyOsuomP+jpAOoRfYySeCmmK/EzL799WQukaaLMmDdA=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # The VPU Makefile expects COMPASS_DRV_BTENVAR_KPATH to be the kernel build directory
  makeFlags = [
    "COMPASS_DRV_BTENVAR_KPATH=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ]
  ++ lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
    "ARCH=${stdenv.hostPlatform.linuxArch}"
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/vpu
    install -D -m 644 amvx.ko $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/vpu/amvx.ko

    runHook postInstall
  '';

  meta = with lib; {
    description = "CIX P1 VPU Driver (amvx)";
    homepage = "https://github.com/cixtech/cix_opensource__vpu_driver";
    license = licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
