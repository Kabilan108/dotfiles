{
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  linkFarm,
  lib,
}:
buildGoModule rec {
  pname = "cliproxyapi";
  version = "8.0.51";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-lzhmN2BRKTod1ewQdE0n9N6ZEj3MUwNBoBAZNowdtGs=";
  };

  vendorHash = "sha256-yMO0DdE0pjtFxWaQXV17enV8u0KA5fIUbE8Gui/RvWU=";
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

  # Update the portal and backend together; the service serves this immutable asset.
  passthru.managementPanel = linkFarm "cliproxyapi-management-panel-1.27.2" [
    {
      name = "management.html";
      path = fetchurl {
        name = "management.html";
        url = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v1.27.2/management.html";
        hash = "sha256-L2z1eoykrOH63eAoDL1BCE9WmZc40OaSowsTVCD3/DA=";
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
