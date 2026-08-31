{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  gpu-screen-recorder,
  meetingMinutesPath,
}:
let
  runtimeInputs = [ gpu-screen-recorder ];
in
stdenvNoCC.mkDerivation {
  pname = "stillsuit-recorder";
  version = "0.1.0";

  src = ../../bin/stillsuit-recorder;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm0755 "$src" "$out/libexec/stillsuit-recorder"
    substituteInPlace "$out/libexec/stillsuit-recorder" \
      --replace-fail '#!/usr/bin/env python3' '#!${lib.getExe python3}' \
      --replace-fail 'MEETING_HELPER = Path.home() / "bin/meeting-minutes"' \
        'MEETING_HELPER = Path("${meetingMinutesPath}")'
    makeWrapper "$out/libexec/stillsuit-recorder" "$out/bin/stillsuit-recorder" \
      --set PATH ${lib.escapeShellArg (lib.makeBinPath runtimeInputs)}

    runHook postInstall
  '';

  passthru = {
    inherit runtimeInputs;
  };

  meta = {
    description = "Fixed-action Stillsuit screen-recorder helper";
    license = lib.licenses.mit;
    mainProgram = "stillsuit-recorder";
    platforms = lib.platforms.linux;
  };
}
