{
  lib,
  fetchurl,
  appimageTools,
  pkgs,
  ...
}:
let
  pname = "BambuStudio";
  version = "02.07.01.62";
  calver = "20260616195227";

  src = fetchurl {
    url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu24.04-v${version}-${calver}.AppImage";
    hash = "sha256-+pi2CFMt+7uysJMUg6rEHlf7GcF1osx719Uo1eD7soc=";
  };

  # AppImages are type 1 (ISO) or type 2 (ELF)
  # file -k type1.AppImage
  #   (SYSV) ISO 9660 CD-ROM filesystem
  # file -k type2.AppImage
  #   (SYSV) (Lepton 3.x), scale 232-60668
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    # Install the AppImage binary
    if [[ -f $out/bin/${pname}-${version} ]];
    then
      mv $out/bin/${pname}-${version} $out/bin/${pname}
    fi

    # Create the AppImage shortcut
    install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  extraPkgs =
    pkgs: with pkgs; [
      openssl
      webkitgtk_4_1
      glib-networking
      xdg-utils
    ];

  profile = ''
    export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules"
  '';

  meta = {
    description = "PC Software for BambuLab and other 3D printers";
    homepage = "https://github.com/bambulab/BambuStudio";
    downloadPage = "https://github.com/bambulab/BambuStudio/releases";
    license = "GNU Affero General Public License v3.0";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ ];
    platforms = [ "x86_64-linux" ];
  };
}
