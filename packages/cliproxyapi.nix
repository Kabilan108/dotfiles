{
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  linkFarm,
  lib,
}:
buildGoModule rec {
  pname = "cliproxyapi";
  version = "8.0.9";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-H1yJdqAZIHrkfOMQm/xaOwVClJZ1sjJ9rk4W2sn75kE=";
  };

  vendorHash = "sha256-r3yWkdMcM40G9jV7MxW/qNv3E9WrHavFilW24quEf+8=";
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
  passthru.managementPanel = linkFarm "cliproxyapi-management-panel-1.25.2" [
    {
      name = "management.html";
      path = fetchurl {
        name = "management.html";
        url = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v1.25.2/management.html";
        hash = "sha256-tuoLvR972yo9pdlgpa1xvInzMhLs4hEkw5BRHu984EE=";
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
