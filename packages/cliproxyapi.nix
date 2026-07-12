{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule rec {
  pname = "cliproxyapi";
  version = "7.2.67";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-kCDufWfeC1h7enfA8Ef7ff88d9ZVGVqh1FKP9Z+/qb4=";
  };

  vendorHash = "sha256-vQU3hLDga5PMUwH4KSB3T5sZ1uPUgHQHeyQGJTKHIYs=";
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

  meta = {
    description = "OpenAI, Claude, Gemini, and Codex compatible proxy for CLI subscriptions";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = "cli-proxy-api";
    platforms = lib.platforms.linux;
  };
}
