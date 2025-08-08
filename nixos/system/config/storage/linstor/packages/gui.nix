{
  fetchurl,
  lib,
  stdenv,
  dpkg,
}:

let
  #########################
  # Web UI Package Variables
  #########################

  packageName = "linstor-gui";
  packageVersion = "1.9.9-1";

  #########################
  # Web UI Package Sources
  #########################

  sources = {
    linstor-gui = fetchurl {
      url = "https://packages.linbit.com/public/dists/proxmox-8/drbd-9/pool/${packageName}_${packageVersion}_all.deb";
      sha256 = "1zi4k21sa93gfgfr0fw5dizr7wjb6n11mc3785mn55m0ik00zm0j";
    };
  };

in

stdenv.mkDerivation rec {
  pname = packageName;
  version = packageVersion;

  src = sources.linstor-gui;

  nativeBuildInputs = [ dpkg ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    runHook preUnpack

    mkdir -p source
    cd source

    echo "Extracting $src..."
    dpkg-deb -x "$src" .

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/linstor-gui

    if [ -d usr/share/linstor-gui ];
    then
      cp -r usr/share/linstor-gui/* $out/share/linstor-gui/
    elif [ -d usr/share/linstor-server/ui ];
    then
      cp -r usr/share/linstor-server/ui/* $out/share/linstor-gui/
    elif [ -d opt/linstor-gui ];
    then
      cp -r opt/linstor-gui/* $out/share/linstor-gui/
    else
      echo "Could not locate UI assets in the Debian package. Contents:"
      find . -maxdepth 4 -type d -name "*linstor*" -print || true
      exit 1
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "LINSTOR Web UI static assets packaged for NixOS";
    homepage = "https://linbit.com/linbit-gui/";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [ maintainers.mahdtech ];
  };
}
