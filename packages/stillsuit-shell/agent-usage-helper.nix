{
  agyBin,
  codexBin,
  python3,
  runCommand,
  writeShellApplication,
}:

let
  userAgents = runCommand "stillsuit-user-agents" { } ''
    mkdir -p $out/bin
    ln -s ${agyBin} $out/bin/agy
    ln -s ${codexBin} $out/bin/codex
  '';
in
writeShellApplication {
  name = "stillsuit-agent-usage";
  runtimeInputs = [
    userAgents
    python3
  ];
  text = ''
    exec python3 ${./bin/stillsuit-agent-usage}
  '';
}
