{
  fetchurl,
  lib,
  makeWrapper,
  patchelf,
  stdenv,
}:
stdenv.mkDerivation rec {
  pname = "pi-coding-agent";
  version = "0.85.1";

  src = fetchurl {
    url = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-linux-arm64.tar.gz";
    hash = "sha256-BC0grohe5POxAoFfMoC5YsN3sun7RN5AN5CMxTDq5NQ=";
  };

  sourceRoot = "pi";
  nativeBuildInputs = [ makeWrapper ];
  dontPatchELF = true;
  dontStrip = true;

  # Pi is a Bun compiled executable. Broad ELF rewriting strips/corrupts its
  # appended application payload, so only replace the dynamic interpreter.
  postPatch = ''
    ${lib.getExe patchelf} --set-interpreter ${stdenv.cc.bintools.dynamicLinker} pi
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/pi"
    cp -R . "$out/libexec/pi"
    makeWrapper "$out/libexec/pi/pi" "$out/bin/pi" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          stdenv.cc.libc
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Pi coding agent CLI";
    homepage = "https://github.com/earendil-works/pi";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = [ "aarch64-linux" ];
  };
}
