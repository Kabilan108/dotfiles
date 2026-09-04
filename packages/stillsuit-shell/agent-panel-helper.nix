{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  codex,
  coreutils,
  ghostty,
  gnugrep,
  jq,
  niri,
  tmux,
  util-linux,
}:
let
  runtimeInputs = [
    bash
    codex
    coreutils
    ghostty
    gnugrep
    jq
    niri
    tmux
    util-linux
  ];
in
stdenvNoCC.mkDerivation {
  pname = "stillsuit-agent-panel";
  version = "0.1.0";

  src = ./bin/stillsuit-agent-panel;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm0755 "$src" "$out/libexec/stillsuit-agent-panel"
    substituteInPlace "$out/libexec/stillsuit-agent-panel" \
      --replace-fail '#!/usr/bin/env bash' '#!${lib.getExe bash}'
    makeWrapper "$out/libexec/stillsuit-agent-panel" "$out/bin/stillsuit-agent-panel" \
      --set PATH ${lib.escapeShellArg (lib.makeBinPath runtimeInputs)}

    runHook postInstall
  '';

  passthru = {
    inherit runtimeInputs;
  };

  meta = {
    description = "Fixed-action Stillsuit Codex quake-panel helper";
    license = lib.licenses.mit;
    mainProgram = "stillsuit-agent-panel";
    platforms = lib.platforms.linux;
  };
}
