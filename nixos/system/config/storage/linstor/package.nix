{
  fetchurl,
  jdk17,
  lib,
  makeWrapper,
  stdenv,
  dpkg,
  gnutar,
  gzip,
}:

let

  packageName = "linstor-server";
  packageVersion = "1.31.3-1";

  linstorController = fetchurl {
    url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/linstor-controller_${packageVersion}_all.deb";
    sha256 = "sha256-0xSeYWYdMBT6ezRLZAOUdA27LCJNDmhAI9mZlsS/Ck0=";
  };

  linstorSatellite = fetchurl {
    url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/linstor-satellite_${packageVersion}_all.deb";
    sha256 = "sha256-ZnUNXszaMf62y7UmI8xNzU0LIXYoK03Py3nxXQE+Da4=";
  };

  linstorCommon = fetchurl {
    url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/linstor-common_${packageVersion}_all.deb";
    sha256 = "sha256-11OBBpFquwlg6GYeujfW/x1cHMTkQ+NJX2coHZbtzKU=";
  };

in

stdenv.mkDerivation rec {
  pname = packageName;
  version = packageVersion;

  srcs = [
    linstorController
    linstorSatellite
    linstorCommon
  ];

  nativeBuildInputs = [
    makeWrapper
    dpkg
    gnutar
    gzip
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

    # Extract each Debian package
    for deb in $srcs;
    do
      echo "Extracting $deb..."
      dpkg-deb -x "$deb" .
    done

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/linstor-server
    mkdir -p $out/bin

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

    # Create wrapper scripts for controller
    makeWrapper ${jdk17}/bin/java $out/bin/linstor-controller \
      --set CLASSPATH "$CLASSPATH" \
      --add-flags "com.linbit.linstor.core.Controller"

    # Create wrapper scripts for satellite
    makeWrapper ${jdk17}/bin/java $out/bin/linstor-satellite \
      --set CLASSPATH "$CLASSPATH" \
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
