{ pkgs }:
let
  pin = builtins.fromJSON (builtins.readFile ./opencode-browse-version.json);
  inherit (pin) version;
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "opencode-browse";
  inherit version;
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@opencode/browse-linux-x64/-/browse-linux-x64-${version}.tgz";
    inherit (pin) hash;
  };
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.libc ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/browse "$out/bin/browse"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    [ "$("$out/bin/browse" version)" = ${pkgs.lib.escapeShellArg version} ]
  '';
  meta = {
    description = "browse relay and MCP server for the browse browser extension";
    homepage = "https://github.com/anomalyco/browse";
    license = pkgs.lib.licenses.mit;
    mainProgram = "browse";
    platforms = [ "x86_64-linux" ];
  };
}
