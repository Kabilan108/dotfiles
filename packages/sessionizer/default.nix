# The fleet tmux session picker. Every host installs it: the laptop runs the
# picker, and other hosts answer its `sessionizer --inventory` and proxy
# commands through "$HOME/bin/sessionizer".
{
  lib,
  buildGoModule,
  makeWrapper,
  openssh,
  tmux,
}:
buildGoModule {
  pname = "sessionizer";
  version = "1.0.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      (lib.fileset.fileFilter (file: file.hasExt "go") ./.)
    ];
  };

  vendorHash = "sha256-BQcJC4Cf6Xt/jrMEwFh5hiae6QekJ5MDCZcgczi3buY=";

  nativeBuildInputs = [ makeWrapper ];

  ldflags = [
    "-s"
    "-w"
  ];

  # Suffix, not prefix: the picker must talk to the tmux server with the
  # user's own tmux. deploy-gate runs it with a bare PATH.
  postInstall = ''
    wrapProgram $out/bin/sessionizer \
      --suffix PATH : ${
        lib.makeBinPath [
          tmux
          openssh
        ]
      }
  '';

  meta.mainProgram = "sessionizer";
}
