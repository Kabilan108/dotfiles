{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "cliproxyapi-openai-only";
  version = "7.2.149";

  src = fetchurl {
    url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_linux_aarch64_no-plugin.tar.gz";
    hash = "sha256-DeuesBBPuE85kCEWK7zjbpZ5D3WlWRLij+CWcUCqeag=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 cli-proxy-api "$out/bin/cli-proxy-api-openai-only"

    runHook postInstall
  '';

  meta = {
    description = "Restricted CLIProxyAPI sidecar for Tleilax coding agents";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = "cli-proxy-api-openai-only";
    platforms = [ "aarch64-linux" ];
  };
}
