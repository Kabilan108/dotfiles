{
  lib,
  stdenvNoCC,
  python3,
  systemdMinimal,
  systemctlProvider ? systemdMinimal,
}:
let
  python = lib.getExe python3;
  systemctl = lib.getExe' systemctlProvider "systemctl";
in
stdenvNoCC.mkDerivation {
  pname = "stillsuit-meeting-enqueue";
  version = "0.1.0";

  src = ../../bin/meeting-minutes;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm0755 "$src" "$out/bin/meeting-minutes"
    substituteInPlace "$out/bin/meeting-minutes" \
      --replace-fail '#!/usr/bin/env python3' '#!${python}' \
      --replace-fail '            "systemctl",' '            "${systemctl}",'

    runHook postInstall
  '';

  passthru.runtimeInputs = [
    python3
    systemctlProvider
  ];

  meta = {
    description = "Store-backed meeting-minutes enqueue entry point";
    license = lib.licenses.mit;
    mainProgram = "meeting-minutes";
    platforms = lib.platforms.linux;
  };
}
