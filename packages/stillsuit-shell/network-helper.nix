{
  networkmanager,
  networkmanagerapplet,
  python3,
  tailscale,
  writeShellApplication,
}:

writeShellApplication {
  name = "stillsuit-network";
  runtimeInputs = [
    networkmanager
    networkmanagerapplet
    python3
    tailscale
  ];
  text = ''
    exec python3 ${./bin/stillsuit-network}
  '';
}
