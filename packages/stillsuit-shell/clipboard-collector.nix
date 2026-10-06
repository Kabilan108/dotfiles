{
  coreutils,
  python3,
  wl-clipboard,
  writeShellApplication,
}:

writeShellApplication {
  name = "stillsuit-clipboard-collector";
  # wl-paste and wl-copy exec `cat` to move clipboard data.
  runtimeInputs = [
    coreutils
    python3
    wl-clipboard
  ];
  # -P keeps the script's directory, the store root, off sys.path; scanning it
  # costs tens of milliseconds on every clipboard change.
  text = ''
    exec python3 -P ${./bin/stillsuit-clipboard-collector} "$@"
  '';
}
