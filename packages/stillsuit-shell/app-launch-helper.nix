{
  lib,
  writeShellApplication,
  coreutils,
  jq,
  libnotify,
  systemd,
}:
writeShellApplication {
  name = "stillsuit-app-launch";
  runtimeInputs = [
    coreutils
    jq
    libnotify
    systemd
  ];
  # The source keeps its own shebang so the fixture can run it directly.
  text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./bin/stillsuit-app-launch);
  meta = {
    description = "Start a Stillsuit launch in its own systemd user scope under app.slice";
    mainProgram = "stillsuit-app-launch";
  };
}
