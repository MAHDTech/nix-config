{ pkgs, ... }:
pkgs.runCommand "zenbook-firmware" {
  nativeBuildInputs = [ pkgs.zstd ];
  srcFirmware = ./files/firmware;
} ''
  mkdir -p $out/lib/firmware
  
  # Copy local extracted blobs (GPU, WiFi, etc)
  if [ -d "$srcFirmware" ]; then
    cp -r --no-preserve=mode,ownership $srcFirmware/* $out/lib/firmware/
  fi

  # Decompress everything so the kernel can read it easily
  find $out/lib/firmware -name "*.zst" -exec zstd -d --rm {} +
''
