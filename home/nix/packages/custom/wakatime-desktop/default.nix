{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:

let
  sources = lib.importJSON ./sources.json;

  pname = "wakatime-desktop";
  inherit (sources) version;

  system = stdenv.hostPlatform.system;
  srcInfo = sources.sources.${system} or (throw "Unsupported platform for ${pname}: ${system}");

  src = fetchurl {
    inherit (srcInfo) url hash;
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/desktop-wakatime.desktop $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'

    if [ -d ${appimageContents}/usr/share/icons ]; then
      mkdir -p $out/share
      cp -r ${appimageContents}/usr/share/icons $out/share/
      chmod -R u+w $out/share
      for icon in $out/share/icons/hicolor/*/apps/desktop-wakatime.png; do
        if [ -f "$icon" ]; then
          ln -s desktop-wakatime.png "$(dirname "$icon")/${pname}.png"
        fi
      done
    fi

    # Symlink alternate binary name desktop-wakatime to wakatime-desktop
    ln -s $out/bin/${pname} $out/bin/desktop-wakatime
  '';

  passthru = {
    inherit sources;
    updateScript = ./update.sh;
  };

  meta = {
    description = "WakaTime desktop application for automated time tracking";
    homepage = "https://wakatime.com";
    downloadPage = "https://github.com/wakatime/desktop-wakatime/releases";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = pname;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
