{
  fetchurl,
  lib,
  stdenv,
  dpkg,
}:

let
  #########################
  # LINSTOR Common Variables
  #########################

  packageVersion = "1.31.3-1";
  packageSha256 = "sha256-11OBBpFquwlg6GYeujfW/x1cHMTkQ+NJX2coHZbtzKU=";

in

stdenv.mkDerivation rec {
  pname = "linstor-common";
  version = packageVersion;

  src = fetchurl {
    url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/linstor-common_${packageVersion}_all.deb";
    sha256 = packageSha256;
  };

  nativeBuildInputs = [ dpkg ];

  unpackPhase = ''
    runHook preUnpack

    mkdir -p source
    cd source

    # Extract the Debian package
    echo "Extracting $src..."
    dpkg-deb -x "$src" .

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Copy the linstor-common files to output
    mkdir -p $out

    # Check for linstor-common files in different possible locations
    if [ -d usr/share/linstor-common ]; then
      echo "Found linstor-common files in usr/share/linstor-common/"
      cp -r usr/share/linstor-common $out/
    elif [ -d usr/share/linstor-server ]; then
      echo "Found linstor-common files in usr/share/linstor-server/"
      cp -r usr/share/linstor-server $out/linstor-common
    elif [ -d usr/share/doc/linstor-common ]; then
      echo "Found linstor-common files in usr/share/doc/linstor-common/"
      cp -r usr/share/doc/linstor-common $out/linstor-common
    else
      echo "linstor-common files not found in extracted package"
      echo "Available directories:"
      find usr -type d -name "*linstor*" || true
      echo "All usr/share contents:"
      ls -la usr/share/ || true
      exit 1
    fi

    # Copy any other relevant files (Python files, etc.)
    find usr -name "*.py" -exec cp --parents {} $out/ \; || true
    find usr -name "*.jar" -exec cp --parents {} $out/ \; || true

    runHook postInstall
  '';

  meta = with lib; {
    description = "LINSTOR common files and utilities";
    homepage = "https://linbit.com/linstor";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
  };
}
