{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  runtimeInputs ? [ ],
}:
let
  runtimePath = lib.makeBinPath runtimeInputs;
in
stdenvNoCC.mkDerivation {
  pname = "stillsuit-shell";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: type:
      let
        relative = lib.removePrefix "${toString ./.}/" (toString path);
      in
      type == "directory"
      || lib.hasPrefix "src/" relative
      || lib.hasPrefix "schemas/" relative
      || lib.hasPrefix "docs/" relative
      || lib.hasPrefix "themes/" relative;
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/stillsuit-shell"
    for directory in src schemas docs themes; do
      if [ -d "$directory" ]; then
        cp -R "$directory" "$out/share/stillsuit-shell/$directory"
      fi
    done

    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe quickshell} "$out/bin/stillsuit-shell" \
      --set PATH ${lib.escapeShellArg runtimePath} \
      --add-flags "--no-duplicate" \
      --add-flags "--path $out/share/stillsuit-shell/src"

    runHook postInstall
  '';

  passthru = {
    inherit runtimeInputs;
    configPath = "${placeholder "out"}/share/stillsuit-shell/src";
  };

  meta = {
    description = "Nix-packaged Stillsuit Quickshell host";
    license = lib.licenses.mit;
    mainProgram = "stillsuit-shell";
    platforms = lib.platforms.linux;
  };
}
