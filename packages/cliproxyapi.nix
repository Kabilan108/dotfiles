{
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  linkFarm,
  lib,
}:
buildGoModule rec {
  pname = "cliproxyapi";
  version = "8.0.67";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-njk9i5JbHvJ3lTB7Bn0wTxFtmcJ5MEokgdOHNhzDPPY=";
  };

  vendorHash = "sha256-02Qqrs9lQ0kE+Tnk/SWvlkLXGSh8RQPxRawFZogRYNc=";
  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=${src.rev}"
  ];

  postInstall = ''
    mv "$out/bin/server" "$out/bin/cli-proxy-api"
  '';

  passthru.managementPanel = linkFarm "cliproxyapi-management-panel-1.27.3" [
    {
      name = "management.html";
      path = fetchurl {
        name = "management.html";
        url = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v1.27.3/management.html";
        hash = "sha256-FNP0ivIpT4v2XMnS2S65pHe0ei+ziib4IN6/aAGgW8k=";
      };
    }
  ];

  meta = {
    description = "OpenAI, Claude, Gemini, and Codex compatible proxy for CLI subscriptions";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = "cli-proxy-api";
    platforms = lib.platforms.linux;
  };
}
