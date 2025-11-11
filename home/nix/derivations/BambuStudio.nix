{
  lib,
  fetchurl,
  appimageTools,
  ...
}:
let
  pname = "BambuStudio";
  version = "2.0.2";

  src = fetchurl {
    url = "https://github.com/bambulab/BambuStudio/releases/download/v02.00.02.57/Bambu_Studio_linux_v02.00.02.57_ubuntu_24.04.AppImage";
    hash = "sha256-SMo3Olmu9X6GpHQSFVgbSXz+06q+jpDG8HJXBKDMaTc=";
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
      #xdg-desktop-portal-cosmic
      #xdg-desktop-portal-gtk
      #xdg-desktop-portal-hyprland
      #xdg-desktop-portal-wlr
      #xdg-launch
      #xdg-utils
    ];

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
