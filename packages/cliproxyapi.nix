{
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  linkFarm,
  lib,
}:
buildGoModule rec {
  pname = "cliproxyapi";
  version = "8.0.77";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-8C6m5aSrQN4HiGcNhCJDvoepFHy/bAYOPnrGdrUnSiU=";
  };

  vendorHash = "sha256-89DZv8uj0rD5fgbfLZk6TuoYw2SfX1vhV88T4degwg8=";
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

  passthru.managementPanel = linkFarm "cliproxyapi-management-panel-1.28.3" [
    {
      name = "management.html";
      path = fetchurl {
        name = "management.html";
        url = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v1.28.3/management.html";
        hash = "sha256-bU4AVCDuGIme8RWk5o1h9wDds3KETyMXVGoNCqRVPfw=";
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
