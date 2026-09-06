{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  python3,
  quickshell,
  sway,
  stillsuit-shell,
  stillsuit-plugins,
}:
let
  runtimeInputs = [
    bash
    coreutils
    python3
    quickshell
    sway
    stillsuit-plugins
  ];
in
stdenvNoCC.mkDerivation {
  pname = "stillsuit-workbench";
  version = "0.1.0";

  src = ./bin/stillsuit-workbench;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm0755 "$src" "$out/libexec/stillsuit-workbench"
    substituteInPlace "$out/libexec/stillsuit-workbench" \
      --replace-fail '#!/usr/bin/env bash' '#!${lib.getExe bash}'
    makeWrapper "$out/libexec/stillsuit-workbench" "$out/bin/stillsuit-workbench" \
      --prefix PATH : ${lib.escapeShellArg (lib.makeBinPath runtimeInputs)} \
      --set-default STILLSUIT_WORKBENCH_PACKAGED_SOURCE \
        "${stillsuit-shell}/share/stillsuit-shell/src"

    runHook postInstall
  '';

  meta = {
    description = "Fixture-backed Stillsuit plugin workbench on a nested compositor";
    license = lib.licenses.mit;
    mainProgram = "stillsuit-workbench";
    platforms = lib.platforms.linux;
  };
}
