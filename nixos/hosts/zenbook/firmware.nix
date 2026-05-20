{ pkgs, ... }:
pkgs.runCommand "zenbook-firmware"
  {
    nativeBuildInputs = [ pkgs.zstd ];
    srcFirmware = ./files/firmware;
  }
  ''
    mkdir -p $out/lib/firmware

    # Copy local extracted blobs (GPU, WiFi, etc)
    if [ -d "$srcFirmware" ]; then
      cp -r --no-preserve=mode,ownership $srcFirmware/* $out/lib/firmware/
    fi

    # The Zenbook A14 only uses Snapdragon X Elite (x1e80100).
    # Move firmware from x1p42100 (Plus) to x1e80100 (Elite) if it exists.
    if [ -d "$out/lib/firmware/qcom/x1p42100" ]; then
      mkdir -p $out/lib/firmware/qcom/x1e80100
      mv $out/lib/firmware/qcom/x1p42100/ASUSTeK $out/lib/firmware/qcom/x1e80100/
      rm -rf $out/lib/firmware/qcom/x1p42100
    fi

    # Decompress everything so the kernel can read it easily
    find $out/lib/firmware -name "*.zst" -exec zstd -d --rm {} +
  ''
