{ python3, writeShellApplication }:
writeShellApplication {
  name = "stillsuit-remmina-list";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 ${./bin/stillsuit-remmina-list}
  '';
}
