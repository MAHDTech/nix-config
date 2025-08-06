{
  dpkg,
  fetchurl,
  gnutar,
  gzip,
  lib,
  makeWrapper,
  python311,
  stdenv,
}:

let
  #########################
  # Client Package Variables
  #########################

  packageName = "linstor-client";
  packageVersion = "1.25.3-1";

  pythonVersion = "3.11";

  #########################
  # Client Package Dependencies
  #########################

  dependencies = {

    linstor-common = import ./common.nix {
      inherit
        fetchurl
        lib
        stdenv
        dpkg
        ;
    };

  };

  #########################
  # Client Package Sources
  #########################

  sources = {

    linstor-client = fetchurl {
      url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/linstor-client_${packageVersion}_all.deb";
      sha256 = "sha256-yNBQlPdnn8Is5kWW9xkKe+XC8jMyF0vqgUCvTORn8NU=";
    };

    python-linstor = fetchurl {
      url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/python-linstor_${packageVersion}_all.deb";
      sha256 = "sha256-njcKKvmcfKR/5JIzw1MUYJzrp9pceXGJ0m+c69Rk+nY=";
    };

  };

in

stdenv.mkDerivation rec {
  pname = packageName;
  version = packageVersion;

  srcs = [
    sources.linstor-client
    sources.python-linstor
  ];

  nativeBuildInputs = [
    dpkg
    gnutar
    gzip
    makeWrapper
  ];

  buildInputs = [
    python311
    python311.pkgs.setuptools
  ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    runHook preUnpack

    mkdir -p source
    cd source

    # Copy linstor-common files
    if [ -d "${dependencies.linstor-common}/usr/share/linstor-server" ];
    then
      echo "Copying linstor-common files from usr/share/linstor-server/..."
      cp -r ${dependencies.linstor-common}/usr/share/linstor-server/* ./ || true
    elif [ -d "${dependencies.linstor-common}/linstor-common" ];
    then
      echo "Copying linstor-common files from linstor-common/..."
      cp -r ${dependencies.linstor-common}/linstor-common/* ./ || true
    else
      echo "linstor-common files not found"
      echo "Available directories in linstor-common:"
      find ${dependencies.linstor-common} -type d || true
      exit 1
    fi

    # Extract DEB packages (both linstor-client and python-linstor)
    for deb in $srcs;
    do
      echo "Extracting $deb..."

      # Create a temporary directory for extraction
      temp_extract=$(mktemp -d)

      # Extract to temporary directory first
      dpkg-deb -x "$deb" "$temp_extract" || {
        echo "Warning: Some files failed to extract from $deb, continuing..."
      }

      # Copy only the files we need, excluding problematic systemd files
      if [ -d "$temp_extract/usr" ]; then
        cp -r "$temp_extract/usr" ./ || true
      fi

      # Copy any other useful directories, but skip systemd-related ones
      for dir in "$temp_extract"/*; do
        if [ -d "$dir" ]; then
          dirname=$(basename "$dir")
          case "$dirname" in
            "lib"|"var")
              echo "Skipping system directory: $dirname"
              ;;
            *)
              cp -r "$dir" ./ || true
              ;;
          esac
        fi
      done

      # Clean up temporary directory
      rm -rf "$temp_extract"
    done

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/lib/python${pythonVersion}/site-packages
    mkdir -p $out/share

    echo "Installing LINSTOR client files from Debian packages..."

    # Copy Python modules from both packages with correct paths
    # linstor-client uses: usr/lib/python3/dist-packages
    # python-linstor uses: usr/lib/python${pythonVersion}/dist-packages
    for python_path in "usr/lib/python3/dist-packages" "usr/lib/python${pythonVersion}/dist-packages"; do
      if [ -d "$python_path" ]; then
        echo "Copying Python modules from $python_path/"
        cp -r "$python_path"/* $out/lib/python${pythonVersion}/site-packages/
      fi
    done

    # Copy share files (documentation, etc.)
    if [ -d "usr/share" ]; then
      cp -r usr/share/* $out/share/ || true
    fi

    # Copy etc files (configuration, completion scripts)
    if [ -d "etc" ]; then
      mkdir -p $out/etc
      cp -r etc/* $out/etc/ || true
    fi

    # Create a wrapper for the linstor binary that sets PYTHONPATH
    if [ -f "usr/bin/linstor" ]; then
      # Copy the original script to a different location
      cp usr/bin/linstor $out/bin/linstor-unwrapped

      # Create a wrapper that sets PYTHONPATH and calls the original script
      makeWrapper $out/bin/linstor-unwrapped $out/bin/linstor \
        --set PYTHONPATH "$out/lib/python${pythonVersion}/site-packages:${python311.pkgs.setuptools}/${python311.sitePackages}"
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "LINSTOR client for managing distributed block storage";
    homepage = "https://linbit.com/linstor";
    license = licenses.gpl2Plus;
    maintainers = [ maintainers.mahdtech ];
    platforms = platforms.linux;
  };
}
