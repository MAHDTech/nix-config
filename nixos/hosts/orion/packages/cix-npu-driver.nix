{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
}:

stdenv.mkDerivation rec {
  pname = "cix-npu-driver";
  version = "mainline_dev-${kernel.version}";

  src = fetchFromGitHub {
    owner = "cixtech";
    repo = "cix_opensource__npu_driver";
    rev = "193d3650645b1d3de9794aa024675c755d864d57"; # Apr 8, 2026 (DPTSW-24094)
    hash = "sha256-eq95TOZwG7lisyq5koSaoRK4QB+QVQcgDJj+3Ekgf2s=";
  };

  patches = [
    ./cix-npu-driver-race-condition-fix.patch
  ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # The NPU Makefile expects COMPASS_DRV_BTENVAR_KPATH to be the kernel build directory
  makeFlags = [
    "COMPASS_DRV_BTENVAR_KPATH=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "BUILD_TARGET_PLATFORM_KMD=BUILD_PLATFORM_SKY1"
    "BUILD_AIPU_VERSION_KMD=BUILD_ZHOUYI_V3"
    "BUILD_NPU_DEVFREQ=y"
    "COMPASS_DRV_BTENVAR_KMD_VERSION=6.1.0"
  ]
  ++ lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform) [
    "ARCH=${stdenv.hostPlatform.linuxArch}"
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
  ];

  # The NPU Makefile is actually inside the driver/ subdirectory,
  # but the top-level make might call it. Let's build from driver/.
  sourceRoot = "${src.name}/driver";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/npu
    install -D -m 644 aipu.ko $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/npu/aipu.ko

    runHook postInstall
  '';

  meta = with lib; {
    description = "CIX P1 NPU Driver (aipu)";
    homepage = "https://github.com/cixtech/cix_opensource__npu_driver";
    license = licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
