{ lib, pkgs }:
pkgs.writeShellApplication {
  name = "stillsuit-plugins";
  text = ''
    exec ${lib.getExe (pkgs.python3.withPackages (p: [ p.jsonschema ]))} ${./bin/stillsuit-plugins} "$@"
  '';
}
