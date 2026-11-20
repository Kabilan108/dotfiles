{
  lib,
  buildGoModule,
  git,
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

  postInstall = ''
    wrapProgram $out/bin/sessionizer \
      --suffix PATH : ${
        lib.makeBinPath [
          tmux
          openssh
          git
        ]
      }
  '';

  meta.mainProgram = "sessionizer";
}
