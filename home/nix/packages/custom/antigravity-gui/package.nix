{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  # Dependencies
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libGL,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  # X11 dependencies (top-level)
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
  libxshmfence,
}:

let
  sources = lib.importJSON ./sources.json;
in
stdenv.mkDerivation {
  pname = "antigravity-gui";
  inherit (sources) version;

  strictDeps = true;

  src = fetchurl {
    inherit
      (sources.sources.${stdenv.hostPlatform.system}
        or (throw "Unsupported system: ${stdenv.hostPlatform.system}")
      )
      url
      sha512
      ;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libGL
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
    libxshmfence
  ];

  # The archive contains a single directory: Antigravity-x64 or Antigravity-arm64
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/antigravity-gui
    cp -r Antigravity-*/* $out/opt/antigravity-gui/

    # Create symlink/wrapper
    mkdir -p $out/bin
    makeWrapper $out/opt/antigravity-gui/antigravity $out/bin/antigravity-gui \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libGL ]}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Antigravity 2.0 GUI - A powerful visual workspace for agentic workflows";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "antigravity-gui";
  };
}
