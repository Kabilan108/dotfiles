{
  codexBin,
  python3,
  runCommand,
  writeShellApplication,
}:

let
  # Probe usage with the codex update-agents installs, the same one used
  # interactively, not a second copy from nixpkgs. Only codex is exposed.
  userCodex = runCommand "stillsuit-user-codex" { } ''
    mkdir -p $out/bin
    ln -s ${codexBin} $out/bin/codex
  '';
in
writeShellApplication {
  name = "stillsuit-agent-usage";
  runtimeInputs = [
    userCodex
    python3
  ];
  text = ''
    exec python3 ${./bin/stillsuit-agent-usage}
  '';
}
