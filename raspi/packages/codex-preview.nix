{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "codex-preview";
  version = "0.155.1";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-aarch64-unknown-linux-musl.tar.gz";
    hash = "sha256-cYV9vJvqNhNBDoppz7RrB8BALW0g/sGIQ9uv/XV2NL0=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    tar -xzf "$src" -C "$out"

    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI pinned for the Tleilax T3 preview";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [ "aarch64-linux" ];
  };
}
