{
  codex,
  python3,
  writeShellApplication,
}:

writeShellApplication {
  name = "stillsuit-agent-usage";
  runtimeInputs = [
    codex
    python3
  ];
  text = ''
    exec python3 ${./bin/stillsuit-agent-usage}
  '';
}
