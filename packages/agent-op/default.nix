# The setgid helper behind `agent-op`. modules/nixos/agent-op.nix builds it
# with the host's paths and installs it as /run/wrappers/bin/agent-op.
{
  lib,
  buildGoModule,
  tokenFile,
  opProgram,
  selfProgram,
}:
buildGoModule {
  pname = "agent-op";
  version = "1.0.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      (lib.fileset.fileFilter (file: file.hasExt "go") ./.)
    ];
  };

  vendorHash = null;

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X main.tokenFile=${tokenFile}"
    "-X main.opProgram=${opProgram}"
    "-X main.selfProgram=${selfProgram}"
  ];

  checkPhase = ''
    runHook preCheck
    go test -count=1 ./...
    runHook postCheck
  '';

  meta.mainProgram = "agent-op";
}
