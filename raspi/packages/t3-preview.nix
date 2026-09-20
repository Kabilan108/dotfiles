{
  fetchurl,
  lib,
  makeWrapper,
  patchelf,
  stdenv,
}:
stdenv.mkDerivation rec {
  pname = "t3-preview";
  version = "0.0.43-preview.20260918.1887";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/t3-${version}-linux-arm64.tar.gz";
    hash = "sha256-+VJ81rV14UeRXFRrYfYLSzfHnWl6ccVaAt6itEDSEyU=";
  };

  sourceRoot = "t3-${version}-linux-arm64";
  nativeBuildInputs = [ makeWrapper ];
  dontPatchELF = true;
  dontStrip = true;

  # This is a Node single-executable application with an appended SEA payload.
  # autoPatchelf rewrites enough of the ELF to corrupt that payload. Changing
  # only the interpreter preserves it; the wrapper supplies the remaining libs.
  postPatch = ''
    ${lib.getExe patchelf} --set-interpreter ${stdenv.cc.bintools.dynamicLinker} t3
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/t3-preview"
    cp -R . "$out/libexec/t3-preview"
    makeWrapper "$out/libexec/t3-preview/t3" "$out/bin/t3-preview" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          stdenv.cc.libc
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "T3 Code Orchestrator v2 preview server";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    mainProgram = "t3-preview";
    platforms = [ "aarch64-linux" ];
  };
}
