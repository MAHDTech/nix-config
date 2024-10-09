{
  lib,
  fetchurl,
  appimageTools,
  ...
}: let
  pname = "cursor";
  version = "0.41.3";
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://downloader.cursor.sh/linux/appImage/x64";
    hash = "sha256-WtfyiNGnUn8g1HR0TQPyn3SMJmjqe+otAYeyokMIO+w=";
  };

  # AppImages are type 1 (ISO) or type 2 (ELF)
  # file -k type1.AppImage
  #   (SYSV) ISO 9660 CD-ROM filesystem
  # file -k type2.AppImage
  #   (SYSV) (Lepton 3.x), scale 232-60668
  appimageContents = appimageTools.extractType2 {
    inherit name src;
  };
in
  appimageTools.wrapType2 {
    inherit name src;

    extraInstallCommands = ''
      # Install the AppImage binary
      mv $out/bin/${name} $out/bin/${pname}

      # Create the AppImage shortcut
      install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      cp -r ${appimageContents}/usr/share/icons $out/share
    '';

    extraPkgs = pkgs:
      with pkgs; [
        xdg-desktop-portal-cosmic
        xdg-desktop-portal-cosmic
        xdg-desktop-portal-gtk
        xdg-desktop-portal-wlr
        xdg-launch
        xdg-utils
      ];

    meta = {
      description = "Cursor is an AI-first coding environment.";
      homepage = "https://cursor.com";
      downloadPage = "https://cursor.com";
      license = "Commercial";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      maintainers = with lib.maintainers; [];
      platforms = ["x86_64-linux"];
    };
  }
