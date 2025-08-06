{
  dpkg,
  fetchurl,
  gnutar,
  gzip,
  jdk17,
  lib,
  makeWrapper,
  stdenv,
}:

let
  #########################
  # Server Package Variables
  #########################

  packageName = "linstor-server";
  packageVersion = "1.31.3-1";

  #########################
  # Server Package Dependencies
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
  # Server Package Sources
  #########################

  sources = {

    linstor-controller = fetchurl {
      url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/linstor-controller_${packageVersion}_all.deb";
      sha256 = "sha256-0xSeYWYdMBT6ezRLZAOUdA27LCJNDmhAI9mZlsS/Ck0=";
    };

    linstor-satellite = fetchurl {
      url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/linstor-satellite_${packageVersion}_all.deb";
      sha256 = "sha256-ZnUNXszaMf62y7UmI8xNzU0LIXYoK03Py3nxXQE+Da4=";
    };

  };

in

stdenv.mkDerivation rec {
  pname = packageName;
  version = packageVersion;

  srcs = [
    sources.linstor-controller
    sources.linstor-satellite
  ];

  nativeBuildInputs = [
    dpkg
    gnutar
    gzip
    makeWrapper
  ];

  buildInputs = [
    jdk17
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

    # Extract DEB source packages.
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
            "lib"|"etc"|"var")
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
    mkdir -p $out/share/linstor-server

    echo "Installing LINSTOR files from Debian packages..."

    # Copy JAR files from the extracted Debian packages
    if [ -d "usr/share/linstor-server" ];
    then
      cp -r usr/share/linstor-server/* $out/share/linstor-server/
    fi

    # Copy any additional lib files
    if [ -d "usr/share/java" ]; then
      cp -r usr/share/java/* $out/share/linstor-server/ || true
    fi

    # Look for JAR files in standard Debian Java locations
    find usr -name "*.jar" -exec cp {} $out/share/linstor-server/ \; || true

    # Also look for JAR files from linstor-common (copied to working directory root)
    find . -maxdepth 2 -name "*.jar" -exec cp {} $out/share/linstor-server/ \; || true

    # Build explicit classpath from all JAR files
    echo "Building classpath from available JAR files..."
    CLASSPATH=""
    for jar in $out/share/linstor-server/*.jar; do
      if [ -f "$jar" ]; then
        if [ -n "$CLASSPATH" ]; then
          CLASSPATH="$CLASSPATH:$jar"
        else
          CLASSPATH="$jar"
        fi
      fi
    done
    echo "Classpath: $CLASSPATH"

    # Create wrapper scripts for controller with proper JVM options
    makeWrapper ${jdk17}/bin/java $out/bin/linstor-controller \
      --set CLASSPATH "$CLASSPATH" \
      --add-flags "-Xms256M" \
      --add-flags "-Xmx8G" \
      --add-flags "-XX:+CrashOnOutOfMemoryError" \
      --add-flags "-Djava.net.preferIPv4Addresses=true" \
      --add-flags "-Djava.net.preferIPv4Stack=true" \
      --add-flags "com.linbit.linstor.core.Controller"

    # Create wrapper scripts for satellite with proper JVM options
    makeWrapper ${jdk17}/bin/java $out/bin/linstor-satellite \
      --set CLASSPATH "$CLASSPATH" \
      --add-flags "-Xms128M" \
      --add-flags "-Xmx4G" \
      --add-flags "-XX:+CrashOnOutOfMemoryError" \
      --add-flags "-Djava.net.preferIPv4Addresses=true" \
      --add-flags "-Djava.net.preferIPv4Stack=true" \
      --add-flags "com.linbit.linstor.core.Satellite"

    runHook postInstall
  '';

  meta = with lib; {
    description = "LINSTOR server for managing distributed block storage";
    homepage = "https://linbit.com/linstor";
    license = licenses.gpl2Plus;
    maintainers = [ maintainers.mahdtech ];
    platforms = platforms.linux;
  };
}
