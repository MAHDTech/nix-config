{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # The actual kernel build
  kernelBuild = pkgs.stdenv.mkDerivation {
    pname = "latest-zenbook";
    # Set version to match what linux-next reports to avoid mismatch
    version = "7.1.0-rc5-next-20260528";

    # Pull the absolute latest bleeding edge where Zenbook support lives
    src = pkgs.fetchgit {
      url = "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git";
      # Use the revision mentioned in the README as tested
      rev = "next-20260528";
      sha256 = "sha256-86TmX6XmHk0pLorcK/ZQ5AHsGj/c6mKQlLdT0DX2ltA=";
    };

    nativeBuildInputs = with pkgs; [
      perl
      bc
      nettools
      openssl
      rsync
      gmp
      libmpc
      mpfr
      util-linux
      elfutils
      flex
      bison
      zstd
      gnumake
      python3
      kmod
    ];

    # Apply the patches from the input.
    prePatch = ''
      echo "Applying Zenbook patches from ${inputs.zenbook-linux}..."
      for patch in ${inputs.zenbook-linux}/*.patch; do
        echo "Applying $patch"
        patch -p1 < "$patch"
      done

      echo "Fixing DTSI camera errors (camss/cci1/csiphy missing in this linux-next)..."
      # Comment out the camera sections that refer to missing labels
      sed -i '/&camss {/,/^};/s/^/\/\//' arch/arm64/boot/dts/qcom/x1-asus-zenbook-a14.dtsi
      sed -i '/&cci1 {/,/^};/s/^/\/\//' arch/arm64/boot/dts/qcom/x1-asus-zenbook-a14.dtsi
      sed -i '/&cci1_i2c1 {/,/^};/s/^/\/\//' arch/arm64/boot/dts/qcom/x1-asus-zenbook-a14.dtsi
      sed -i '/&csiphy4 {/,/^};/s/^/\/\//' arch/arm64/boot/dts/qcom/x1-asus-zenbook-a14.dtsi
    '';

    configurePhase = ''
      patchShebangs scripts/config

      # Use our beautifully optimized whitelisted config (Automated Hardware Profile)
      cp ${./files/config/zenbook.defconfig} .config

      # Re-sync configuration against the active kernel tree
      make ARCH=arm64 olddefconfig
    '';

    buildPhase = ''
      make ARCH=arm64 -j$NIX_BUILD_CORES
    '';

    installPhase = ''
      mkdir -p $out/boot
      cp arch/arm64/boot/Image $out/boot/vmlinuz
      cp arch/arm64/boot/Image $out/Image
      cp .config $out/config
      make ARCH=arm64 modules_install INSTALL_MOD_PATH=$out
      make ARCH=arm64 dtbs_install INSTALL_DTBS_PATH=$out/dtbs

      # Delete dangling symlinks that point to the build directory
      rm -rf $out/lib/modules/*/build
      rm -rf $out/lib/modules/*/source
    '';

    # satisfy the kernel modules expectations
    passthru = rec {
      modDirVersion = "7.1.0-rc5-next-20260528";
      version = modDirVersion;
      dev = kernelBuild;
      moduleBuildDependencies = [ ];
      configfile = "${kernelBuild}/config";
      config = {
        isEnabled = _: true;
        isYes = _: true;
        isNo = _: false;
        isModule = _: false;
        isSet = _: true;
      };
      kernelOlder = v: lib.versionOlder version v;
      kernelAtLeast = v: lib.versionAtLeast version v;
      features = {
        efiBootStub = true;
      };
      commonMakeFlags = [ "ARCH=arm64" ];
    };
  };
in
kernelBuild
