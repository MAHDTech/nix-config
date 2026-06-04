{ pkgs, ... }:

# Derivation to unpack the Qualcomm Windows Graphics Driver ZIP package
# and extract the Linux-relevant firmware files for Zenbook.
pkgs.stdenv.mkDerivation {
  pname = "firmware-qualcomm-windows";
  version = "31.0.148.0";

  # Download directly from Qualcomm's public servers at build time
  src = pkgs.fetchurl {
    url = "https://softwarecenter.qualcomm.com/api/download/software/tools/Windows_Graphics_Driver/Windows/ARM64/260228031.0.148.0/Windows_Graphics_Driver.Core.260228031.0.148.0.Windows-ARM64.zip";
    sha256 = "0xji4sys1sid2p3brba0k4hz31lzmyqsg5q0xksb63fb6qp69h9n";
  };

  nativeBuildInputs = with pkgs; [
    unzip
    p7zip
    msitools
    gnugrep
    coreutils
  ];

  # No need for standard unpack phase since we do it inside the custom builder
  dontUnpack = true;

  installPhase = ''
    mkdir -p tmp
    cd tmp

    echo "Extracting outer ZIP archive..."
    unzip -q $src

    # Locate the nested WiX Burn bootstrapper EXE
    exe_path=$(find . -name "*.exe" -type f | head -n1)
    if [[ -z "$exe_path" ]]; then
      echo "ERROR: No EXE found inside ZIP archive"
      exit 1
    fi
    echo "Found EXE: $exe_path"

    # Step 1: Extract WiX Burn bootstrapper payloads
    mkdir stage1
    7z x "$exe_path" -ostage1 -y >/dev/null

    # Step 2: Locate attached CAB container offset by finding the second MSCF magic
    # (first MSCF is the UX CAB, second MSCF is the attached container CAB holding the MSI)
    mscf_offsets=$(grep -boPa 'MSCF' "$exe_path" | head -n2)
    attached_offset=$(echo "$mscf_offsets" | tail -n1 | cut -d: -f1)
    ux_offset=$(echo "$mscf_offsets" | head -n1 | cut -d: -f1)

    if [[ -z "$attached_offset" || "$attached_offset" == "$ux_offset" ]]; then
      echo "ERROR: Cannot locate attached CAB container in EXE"
      exit 1
    fi

    # Read cabinet size from CAB header (bytes 8-11, little-endian u32)
    cab_size_hex=$(dd if="$exe_path" bs=1 skip=$((attached_offset + 8)) count=4 2>/dev/null | od -An -tx1 | tr -d ' ')
    cab_size=$(printf '%d' "0x''${cab_size_hex:6:2}''${cab_size_hex:4:2}''${cab_size_hex:2:2}''${cab_size_hex:0:2}")

    echo "Attached container at offset $attached_offset, size $cab_size"

    # Extract the CAB using dd (using bs=1M and byte flags to prevent extremely slow byte-by-byte copies)
    dd if="$exe_path" of=attached.cab bs=1M iflag=skip_bytes,count_bytes skip="$attached_offset" count="$cab_size" 2>/dev/null

    # Step 3: Extract the CAB to get the MSI
    mkdir cab_out
    7z x attached.cab -ocab_out -y >/dev/null

    # Locate the MSI file
    msi_path=$(find cab_out -type f | head -n1)
    if [[ -z "$msi_path" ]]; then
      echo "ERROR: No MSI found in CAB container"
      exit 1
    fi

    # Step 4: Extract the MSI using msiextract
    mkdir msi_out
    cd msi_out
    msiextract "../$msi_path" >/dev/null
    cd ..

    # Step 5: Locate and copy target firmware files to output path
    out_fw_dir_elite=$out/lib/firmware/qcom/x1e80100/ASUSTeK/zenbook-a14
    out_fw_dir_plus=$out/lib/firmware/qcom/x1p42100/ASUSTeK/zenbook-a14
    mkdir -p $out_fw_dir_elite $out_fw_dir_plus

    firmware_files=(
      qcav1e8380.mbn
      qcdxkmbase8380.bin
      qcdxkmbase8380_68.bin
      qcdxkmbase8380_110.bin
      qcdxkmbase8380_150.bin
      qcdxkmbase8380_pa.bin
      qcdxkmbase8380_pa_67.bin
      qcdxkmbase8380_pa_111.bin
      qcdxkmbase8380_pa_140.bin
      qcdxkmsuc8380.mbn
      qcdxkmsucpurwa.mbn
      qcvss8380.mbn
      qcvss8380_pa.mbn
      sequence_manifest.bin
      unified_kbcs_32.bin
      unified_kbcs_64.bin
      unified_ksqs.bin
    )

    found_count=0
    for fw_name in "''${firmware_files[@]}"; do
      fw_path=$(find msi_out -iname "$fw_name" -type f | head -n1)
      if [[ -n "$fw_path" ]]; then
        cp "$fw_path" "$out_fw_dir_elite/$fw_name"
        cp "$fw_path" "$out_fw_dir_plus/$fw_name"
        found_count=$((found_count + 1))
      fi
    done

    echo "Extracted $found_count firmware files successfully."

    # Remove any dangling symlinks to satisfy Nix's broken symlink checker
    find $out -type l ! -exec test -e {} \; -delete
  '';
}
