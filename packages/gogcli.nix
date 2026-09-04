{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gogcli";
  version = "0.39.0";

  src = fetchurl {
    url = "https://github.com/openclaw/gogcli/releases/download/v${finalAttrs.version}/gogcli_${finalAttrs.version}_linux_amd64.tar.gz";
    hash = "sha256-dhALzhPJdrCs88cXKg5S1MBtqVreQvYgrVdwfNUy8+g=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 gog $out/bin/gog
    runHook postInstall
  '';

  meta = {
    description = "Google Workspace CLI";
    homepage = "https://gogcli.sh";
    license = lib.licenses.mit;
    mainProgram = "gog";
    platforms = [ "x86_64-linux" ];
  };
})
