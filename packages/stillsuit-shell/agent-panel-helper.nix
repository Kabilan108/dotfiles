{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
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
    # The helper's own tools are pinned; the configured agent command resolves
    # against the session PATH that tmux inherits, so any agent can be used.
    makeWrapper "$out/libexec/stillsuit-agent-panel" "$out/bin/stillsuit-agent-panel" \
      --prefix PATH : ${lib.escapeShellArg (lib.makeBinPath runtimeInputs)} \
      --set STILLSUIT_AGENT_PANEL_SELF "$out/bin/stillsuit-agent-panel"

    runHook postInstall
  '';

  passthru = {
    inherit runtimeInputs;
  };

  meta = {
    description = "Fixed-action Stillsuit agent quake-panel helper";
    license = lib.licenses.mit;
    mainProgram = "stillsuit-agent-panel";
    platforms = lib.platforms.linux;
  };
}
