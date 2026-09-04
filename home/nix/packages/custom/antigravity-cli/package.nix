{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:

let
  sources = lib.importJSON ./sources.json;
in
stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit (sources) version;

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchurl {
    inherit
      (sources.sources.${stdenvNoCC.hostPlatform.system}
        or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}")
      )
      url
      sha512
      ;
  };

  sourceRoot = ".";

  # The tarball holds a single prebuilt binary named 'antigravity', installed as 'agy'.
  # ELF platforms need autoPatchelfHook; Mach-O binaries run as shipped.
  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isElf [ autoPatchelfHook ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 antigravity $out/bin/agy

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Antigravity CLI - A powerful tool for agentic workflows";
    homepage = "https://antigravity.google";
    changelog = "https://antigravity.google/changelog";
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "agy";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ ];
  };
}
