# cspell:words asar miniben xwin
{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  asar,
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
    postExtract = ''
            # Patch @miniben90/x-win in app.asar to prevent unconditional Rust panic/crash
            # on Wayland sessions (upstream issue #118) where the private GNOME Shell
            # D-Bus extension is not available.
            mkdir -p asar-work
            ${asar}/bin/asar extract $out/resources/app.asar asar-work
            chmod -R u+w asar-work

            XWIN_JS="asar-work/node_modules/@miniben90/x-win/index.js"
            if [ -f "$XWIN_JS" ]; then
              substituteInPlace "$XWIN_JS" \
                --replace-fail \
                  'const { WindowInfo, activeWindow, activeWindowAsync, openWindows, openWindowsAsync, subscribeActiveWindow, unsubscribeActiveWindow, unsubscribeAllActiveWindow, installExtension, uninstallExtension, enableExtension, disableExtension } = nativeBinding' \
                  'const { WindowInfo, installExtension, uninstallExtension, enableExtension, disableExtension } = nativeBinding;

      function emptyWindow() {
        return {
          id: 0,
          os: "linux",
          title: "",
          position: { width: 0, height: 0, x: 0, y: 0, isFullScreen: false },
          info: { process_id: 0, processId: 0, path: "", name: "", exec_name: "", execName: "" },
          usage: { memory: 0 }
        };
      }

      let activeWindow = function() {
        try { return nativeBinding.activeWindow(); } catch { return emptyWindow(); }
      };

      let activeWindowAsync = async function() {
        try { return await nativeBinding.activeWindowAsync(); } catch { return emptyWindow(); }
      };

      let openWindows = function() {
        try { return nativeBinding.openWindows(); } catch { return []; }
      };

      let openWindowsAsync = async function() {
        try { return await nativeBinding.openWindowsAsync(); } catch { return []; }
      };

      let subscriptionCounter = 1;

      let subscribeActiveWindow = function(callback) {
        if (process.platform === "linux" && process.env.WAYLAND_DISPLAY) {
          return subscriptionCounter++;
        }
        try {
          return nativeBinding.subscribeActiveWindow(callback);
        } catch {
          return subscriptionCounter++;
        }
      };

      let unsubscribeActiveWindow = function(id) {
        try { return nativeBinding.unsubscribeActiveWindow(id); } catch {}
      };

      let unsubscribeAllActiveWindow = function() {
        try { return nativeBinding.unsubscribeAllActiveWindow(); } catch {}
      };

      if (process.platform === "linux" && process.env.WAYLAND_DISPLAY) {
        activeWindow = emptyWindow;
        activeWindowAsync = async () => emptyWindow();
        openWindows = () => [];
        openWindowsAsync = async () => [];
      }'
              chmod +w $out/resources/app.asar
              ${asar}/bin/asar pack asar-work $out/resources/app.asar
            fi
            rm -rf asar-work
    '';
  };
in
(appimageTools.wrapType2 {
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

  profile = ''
    export APPIMAGE="$0"
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
}).overrideAttrs
  (_: {
    contents = appimageContents;
  })
