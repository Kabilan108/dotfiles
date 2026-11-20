{
  coreutils,
  python3,
  wl-clipboard,
  writeShellApplication,
}:

writeShellApplication {
  name = "stillsuit-clipboard-collector";
  runtimeInputs = [
    coreutils
    python3
    wl-clipboard
  ];
  text = ''
    exec python3 -P ${./bin/stillsuit-clipboard-collector} "$@"
  '';
}
