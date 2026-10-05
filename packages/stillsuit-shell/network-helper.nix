{
  coreutils,
  networkmanager,
  networkmanagerapplet,
  python3,
  tailscale,
  util-linux,
  wl-clipboard,
  writeShellApplication,
}:

writeShellApplication {
  name = "stillsuit-network";
  runtimeInputs = [
    coreutils
    networkmanager
    networkmanagerapplet
    python3
    tailscale
    util-linux
    wl-clipboard
  ];
  text = ''
    exec python3 ${./bin/stillsuit-network}
  '';
}
